# Copyright:: Copyright 2024
# License:: The MIT License (MIT)
#
# Open SketchUp Framework v0.2.1 - see AGENTS.md in the repo root.

require 'fileutils'

module Yoo_ProjectChangeLog4Su
  module ProjectChangeLog
    # __dir__ can carry a bad encoding on Windows (paths with non-ASCII
    # characters) - dup + force UTF-8 once, then reuse.
    support_dir = __dir__.dup
    support_dir.force_encoding('UTF-8') if support_dir.respond_to?(:force_encoding)
    SUPPORT_DIR = support_dir.freeze

    # Framework modules, namespaced inside this extension (see AGENTS.md).
    Sketchup.require(File.join(SUPPORT_DIR, 'open_sketchup_helpers'))
    Sketchup.require(File.join(SUPPORT_DIR, 'open_sketchup_html_dialog'))
    Sketchup.require(File.join(SUPPORT_DIR, 'open_sketchup_update_checker'))

    SETTINGS_DICT = 'Yoo_ProjectChangeLog4Su'.freeze

    # Simple CSV helper methods to avoid dependency on Ruby's CSV library
    # which has compatibility issues with SketchUp's Ruby environment.
    module CSVHelper
      def self.escape_csv_value(value)
        value = value.to_s.gsub('"', '""')
        if value.include?(',') || value.include?("\n") || value.include?('"')
          return "\"#{value}\""
        end
        value
      end

      def self.parse_csv_line(line)
        values = []
        current = ''
        in_quotes = false
        i = 0

        while i < line.length
          char = line[i]

          if char == '"'
            if in_quotes && i + 1 < line.length && line[i + 1] == '"'
              current += '"'
              i += 1
            else
              in_quotes = !in_quotes
            end
          elsif char == ',' && !in_quotes
            values << current
            current = ''
          else
            current += char
          end

          i += 1
        end

        values << current
        values
      end
    end

    # ------------------------------------------------------------------------
    # OBSERVERS
    # ------------------------------------------------------------------------

    # We use the AppObserver to attach our ModelObserver to every model
    # that is created or opened.
    class MyAppObserver < Sketchup::AppObserver
      def onNewModel(model)
        Yoo_ProjectChangeLog4Su::ProjectChangeLog.attach_model_observer(model)
      end

      def onOpenModel(model)
        Yoo_ProjectChangeLog4Su::ProjectChangeLog.attach_model_observer(model)
      end
    end

    # The ModelObserver reacts to model events. We specifically want
    # onPostSaveModel so we know the file has been written to disk.
    class MyModelObserver < Sketchup::ModelObserver
      def onPostSaveModel(model)
        Yoo_ProjectChangeLog4Su::ProjectChangeLog.prompt_for_log(model)
      end
    end

    # ------------------------------------------------------------------------
    # CORE FUNCTIONALITY
    # ------------------------------------------------------------------------

    # Helper method to attach model observer without duplicates.
    def self.attach_model_observer(model)
      model.remove_observer(@model_observer) if @model_observer

      @model_observer ||= MyModelObserver.new
      model.add_observer(@model_observer)
    end

    # Settings Management using SketchUp Model Attributes.
    def self.get_setting(model, key, default = nil)
      Helpers.get_attribute(model, key, default: default, dict_name: SETTINGS_DICT)
    end

    def self.set_setting(model, key, value)
      Helpers.set_attribute(model, key, value, dict_name: SETTINGS_DICT)
    end

    # Default is OFF for automatic prompts.
    # Backward compatibility:
    # - If enable_auto_prompts exists, use it.
    # - Otherwise, derive from legacy disable_auto_prompts.
    def self.auto_prompts_enabled?(model)
      enabled_value = get_setting(model, 'enable_auto_prompts', nil)
      return enabled_value unless enabled_value.nil?

      !get_setting(model, 'disable_auto_prompts', true)
    end

    # Push to Master - Copy current file to master location.
    def self.push_to_master(source_path, master_path)
      begin
        master_dir = File.dirname(master_path)
        FileUtils.mkdir_p(master_dir) unless File.directory?(master_dir)

        FileUtils.cp(source_path, master_path)

        # Also copy the changelog file if it exists.
        source_log = source_path.sub(/\.skp\z/i, '_changelog.csv')
        if File.exist?(source_log)
          master_log = master_path.sub(/\.skp\z/i, '_changelog.csv')
          FileUtils.cp(source_log, master_log)
        end

        return true
      rescue => e
        UI.messagebox("Error pushing to master: #{e.message}")
        return false
      end
    end

    def self.get_log_path(model)
      skp_path = model.path
      return nil if skp_path.empty? # Model hasn't been saved yet

      skp_path.sub(/\.skp\z/i, '_changelog.csv')
    end

    # Append one entry to the changelog CSV. Returns true on success.
    def self.append_log_entry(log_path, message)
      timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
      username = ENV['USERNAME'] || ENV['USER'] || 'Unknown'

      File.open(log_path, 'a') do |file|
        row = [timestamp, username, message]
        file.puts(row.map { |val| CSVHelper.escape_csv_value(val) }.join(','))
      end
      puts "Log updated at #{log_path}"
      true
    end

    # Read all changelog rows (oldest first) for the history viewer.
    def self.read_log_entries(log_path)
      rows = []
      File.open(log_path, 'r') do |file|
        file.each_line do |line|
          line.strip!
          rows << CSVHelper.parse_csv_line(line) unless line.empty?
        end
      end
      rows
    end

    # ------------------------------------------------------------------------
    # DIALOGS (Modus UI via HtmlUi - SketchUp 2021.1+ / CEF 88)
    # ------------------------------------------------------------------------

    # Settings Dialog.
    def self.open_settings_dialog
      model = Sketchup.active_model
      return unless model

      dialog = HtmlUi.show(
        html_file: 'settings.html',
        title: 'Project Change Log settings',
        width: 460,
        height: 520,
        preferences_key: 'com.yoo.projectchangelog.settings'
      )

      HtmlUi.on(dialog, 'settings_ready') do |ctx|
        ctx.reply(
          'masterPath' => get_setting(model, 'master_file_path', ''),
          'enableAutoPrompts' => auto_prompts_enabled?(model),
          'skipThresholdMinutes' => get_setting(model, 'skip_threshold_minutes', 5)
        )
      end

      HtmlUi.on(dialog, 'browse_master') do |ctx|
        path = UI.savepanel('Select master file location', '', '*.skp')
        ctx.reply('path' => path.to_s)
      end

      HtmlUi.on(dialog, 'save_settings') do |ctx|
        data = ctx.payload || {}
        enabled = data['enableAutoPrompts'] == true
        Helpers.undo_wrap(model, 'Save change log settings') do
          set_setting(model, 'master_file_path', data['masterPath'].to_s)
          set_setting(model, 'enable_auto_prompts', enabled)
          # Keep legacy key in sync for existing installations.
          set_setting(model, 'disable_auto_prompts', !enabled)
          set_setting(model, 'skip_threshold_minutes', data['skipThresholdMinutes'])
        end
        ctx.reply('success' => true)
      end

      HtmlUi.on(dialog, 'cancel') { |_ctx| dialog.close }
    end

    # Pop up the dialog to ask what changed.
    def self.prompt_for_log(model, force: false)
      log_path = get_log_path(model)
      return unless log_path # Safety check

      # If the commit dialog is already open, don't stack a new one on top -
      # just bring the existing window to the front.
      if @commit_dialog && @commit_dialog.visible?
        @commit_dialog.bring_to_front
        return
      end

      # Skip if auto-prompts are disabled (unless forced by manual trigger).
      return unless force || auto_prompts_enabled?(model)

      # Time-based filtering (unless forced).
      unless force
        last_prompt = get_setting(model, 'last_prompt_time', nil)
        threshold_minutes = get_setting(model, 'skip_threshold_minutes', 5)

        if last_prompt
          begin
            elapsed_minutes = (Time.now - Time.parse(last_prompt)) / 60.0
            return if elapsed_minutes < threshold_minutes
          rescue => e
            # If parsing fails, continue with prompt.
            puts "Error parsing last_prompt_time: #{e.message}"
          end
        end
      end

      # Deliberately NOT wrapped in an undo operation: this write runs inside
      # onPostSaveModel, where starting a model operation is unsafe.
      set_setting(model, 'last_prompt_time', Time.now.to_s)

      dialog = HtmlUi.show(
        html_file: 'commit.html',
        title: 'Commit changes',
        width: 460,
        height: 460,
        resizable: true,
        preferences_key: 'com.yoo.projectchangelog.commit_log_input',
        on_closed: ->(_dlg) { @commit_dialog = nil }
      )
      @commit_dialog = dialog

      HtmlUi.on(dialog, 'commit_ready') do |ctx|
        ctx.reply(
          'masterPath' => get_setting(model, 'master_file_path', ''),
          'pushToMaster' => get_setting(model, 'push_to_master_enabled', false)
        )
      end

      HtmlUi.on(dialog, 'browse_master') do |ctx|
        path = UI.savepanel('Select master file location', '', '*.skp')
        ctx.reply('path' => path.to_s)
      end

      HtmlUi.on(dialog, 'open_settings') do |_ctx|
        dialog.close
        open_settings_dialog
      end

      HtmlUi.on(dialog, 'submit_log') do |ctx|
        data = ctx.payload || {}
        master_path = data['masterPath'].to_s

        append_log_entry(log_path, data['message'].to_s)

        Helpers.undo_wrap(model, 'Save change log settings') do
          set_setting(model, 'push_to_master_enabled', data['pushToMaster'] == true)
          set_setting(model, 'master_file_path', master_path) unless master_path.empty?
        end

        if data['pushToMaster'] == true && !master_path.empty?
          if push_to_master(model.path, master_path)
            ctx.reply('success' => true, 'message' => 'Changes logged and pushed to master.')
          else
            ctx.reply('success' => false,
                      'message' => 'Changes logged, but push to master failed.')
          end
        else
          ctx.reply('success' => true, 'message' => 'Changes logged.')
        end
      end

      HtmlUi.on(dialog, 'cancel') { |_ctx| dialog.close }
    end

    # Viewer for the log.
    def self.open_log_viewer
      model = Sketchup.active_model
      return unless model
      log_path = get_log_path(model)

      unless log_path && File.exist?(log_path)
        UI.messagebox('No log file found. Save the model to start a log.')
        return
      end

      dialog = HtmlUi.show(
        html_file: 'history.html',
        title: 'Project history',
        width: 800,
        height: 600,
        resizable: true,
        preferences_key: 'com.yoo.projectchangelog.log_viewer'
      )

      HtmlUi.on(dialog, 'history_ready') do |ctx|
        rows = read_log_entries(log_path)
        ctx.reply(
          'fileName' => File.basename(model.path),
          'autoPrompts' => auto_prompts_enabled?(model),
          'rows' => rows.reverse.map do |row|
            {
              'timestamp' => row[0].to_s,
              'user' => row[1].to_s,
              'message' => row[2].to_s
            }
          end
        )
      end

      HtmlUi.on(dialog, 'update_auto_prompts') do |ctx|
        enabled = ctx.payload.is_a?(Hash) && ctx.payload['enabled'] == true
        Helpers.undo_wrap(model, 'Save change log settings') do
          set_setting(model, 'enable_auto_prompts', enabled)
          # Keep legacy key in sync for existing installations.
          set_setting(model, 'disable_auto_prompts', !enabled)
        end
        ctx.reply('success' => true)
      end
    end

    # ------------------------------------------------------------------------
    # CAPABILITY REGISTRY (optional - Open SketchUp Registry extension)
    # ------------------------------------------------------------------------

    # Capability entry point: append an entry to the active model's changelog.
    def self.capability_append_entry(message)
      model = Sketchup.active_model
      return false unless model
      log_path = get_log_path(model)
      return false unless log_path

      append_log_entry(log_path, message.to_s)
    end

    def self.register_capabilities
      return true if @capabilities_registered
      return false unless defined?(OpenSketchUp::Registry)

      Helpers.registry_register(
        'export.changelog.append',
        version: '1.0.0',
        description: 'Append an entry to the active model changelog CSV. ' \
                     'Args: message (String). Returns: true on success, ' \
                     'false if the model has not been saved.',
        callable: method(:capability_append_entry)
      )
      @capabilities_registered = true
    end

    register_capabilities
    UI.start_timer(0, false) { register_capabilities } unless @capabilities_registered

    # ------------------------------------------------------------------------
    # INITIALIZATION
    # ------------------------------------------------------------------------
    unless file_loaded?(__FILE__)
      # add_submenu returns the existing submenu when one with the same
      # title exists, so other Yoo extensions share "Yoo Tools" instead of
      # creating a duplicate.
      yoo_tools = UI.menu('Extensions').add_submenu('Yoo Tools')
      submenu = yoo_tools.add_submenu('Project Change Log')
      submenu.add_item('View history') { open_log_viewer }
      submenu.add_item('Log changes now') do
        model = Sketchup.active_model
        if model && !model.path.empty?
          prompt_for_log(model, force: true)
        else
          UI.messagebox('Please save the model first before logging changes.')
        end
      end
      submenu.add_item('Settings...') { open_settings_dialog }

      # Toolbar with a Commit Changes button (icons bundled in images/).
      toolbar = UI::Toolbar.new('Project Change Log')
      commit_cmd = UI::Command.new('Commit Changes') do
        model = Sketchup.active_model
        if model && !model.path.empty?
          prompt_for_log(model, force: true)
        else
          UI.messagebox('Please save the model first before logging changes.')
        end
      end
      images_dir = File.join(SUPPORT_DIR, 'images')
      commit_cmd.small_icon = File.join(images_dir, 'commit_32.png')
      commit_cmd.large_icon = File.join(images_dir, 'commit_48.png')
      commit_cmd.tooltip = 'Commit Changes'
      commit_cmd.status_bar_text = 'Log changes to the project changelog.'
      commit_cmd.menu_text = 'Commit Changes'
      toolbar.add_item(commit_cmd)
      toolbar.restore

      # Create singleton observers.
      @app_observer ||= MyAppObserver.new
      @model_observer ||= MyModelObserver.new

      # Attach the AppObserver to watch for application events.
      Sketchup.add_observer(@app_observer)

      # Attach ModelObserver to the currently active model immediately
      # (onNewModel/onOpenModel won't fire for the model already open when
      # SketchUp starts).
      attach_model_observer(Sketchup.active_model)

      # Async update check (24h cooldown, notify-only per Warehouse policy).
      UpdateChecker.check_for_update(
        extension: EXTENSION,
        current_version: '1.5.0',
        version_url: 'https://raw.githubusercontent.com/jurej/' \
                     'Yoo_ProjectChangeLog4Su/main/version.json',
        download_url: 'https://github.com/jurej/Yoo_ProjectChangeLog4Su/releases'
      )

      file_loaded(__FILE__)
    end
  end
end
