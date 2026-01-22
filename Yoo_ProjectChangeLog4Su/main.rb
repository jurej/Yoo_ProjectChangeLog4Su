# Copyright:: Copyright 2024
# License:: The MIT License (MIT)

require 'fileutils'
require_relative 'dialogs'

module Yoo_ProjectChangeLog4Su
  module ProjectChangeLog
    
    # Simple CSV helper methods to avoid dependency on Ruby's CSV library
    # which has compatibility issues with SketchUp's Ruby environment
    module CSVHelper
      def self.escape_csv_value(value)
        # Convert to string and escape double quotes by doubling them
        value = value.to_s.gsub('"', '""')
        # Wrap in quotes if it contains comma, newline, or quote
        if value.include?(',') || value.include?("\n") || value.include?('"')
          return "\"#{value}\""
        end
        value
      end
      
      def self.parse_csv_line(line)
        # Simple CSV parser for our three-column format
        values = []
        current = ''
        in_quotes = false
        i = 0
        
        while i < line.length
          char = line[i]
          
          if char == '"'
            if in_quotes && i + 1 < line.length && line[i+1] == '"'
              # Double quote inside quoted field
              current += '"'
              i += 1
            else
              # Toggle quote state
              in_quotes = !in_quotes
            end
          elsif char == ',' && !in_quotes
            # Field separator
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
    # that is created or opened[cite: 102, 106].
    class MyAppObserver < Sketchup::AppObserver
      def onNewModel(model)
        Yoo_ProjectChangeLog4Su::ProjectChangeLog.attach_model_observer(model)
      end

      def onOpenModel(model)
        Yoo_ProjectChangeLog4Su::ProjectChangeLog.attach_model_observer(model)
      end
    end

    # The ModelObserver reacts to model events. We specifically want onPostSaveModel
    # so we know the file has been written to disk successfully[cite: 1, 30].
    class MyModelObserver < Sketchup::ModelObserver
      def onPostSaveModel(model)
        # Trigger the log prompt
        Yoo_ProjectChangeLog4Su::ProjectChangeLog.prompt_for_log(model)
      end
    end

    # ------------------------------------------------------------------------
    # CORE FUNCTIONALITY
    # ------------------------------------------------------------------------

    # Helper method to attach model observer without duplicates
    def self.attach_model_observer(model)
      # Remove any existing MyModelObserver instances to prevent duplicates
      model.remove_observer(@model_observer) if @model_observer
      
      # Create or reuse the singleton model observer
      @model_observer ||= MyModelObserver.new
      model.add_observer(@model_observer)
    end

    # Settings Management using SketchUp Model Attributes
    def self.get_setting(model, key, default = nil)
      dict = model.attribute_dictionary('Yoo_ProjectChangeLog4Su', false)
      return default unless dict
      dict[key] || default
    end

    def self.set_setting(model, key, value)
      dict = model.attribute_dictionary('Yoo_ProjectChangeLog4Su', true)
      dict[key] = value
    end

    # Push to Master - Copy current file to master location
    def self.push_to_master(source_path, master_path)
      begin
        # Ensure the master directory exists
        master_dir = File.dirname(master_path)
        FileUtils.mkdir_p(master_dir) unless File.directory?(master_dir)
        
        # Copy the .skp file (always overwrite)
        FileUtils.cp(source_path, master_path)
        
        # Also copy the changelog file if it exists
        source_log = source_path.gsub('.skp', '_changelog.csv')
        if File.exist?(source_log)
          master_log = master_path.gsub('.skp', '_changelog.csv')
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
      
      # Create a .csv path based on the .skp path
      return skp_path.gsub(".skp", "_changelog.csv")
    end

    # Settings Dialog
    def self.open_settings_dialog
      model = Sketchup.active_model
      current_master = get_setting(model, 'master_file_path', '')
      disable_auto_prompts = get_setting(model, 'disable_auto_prompts', false)
      skip_threshold_minutes = get_setting(model, 'skip_threshold_minutes', 5)
      
      dialog = UI::HtmlDialog.new(
        {
          :dialog_title => "Yoo ProjectChangeLog4Su Settings",
          :preferences_key => "com.yoo.projectchangelog.settings",
          :scrollable => true,
          :resizable => true,
          :width => 450,
          :height => 400,
          :style => UI::HtmlDialog::STYLE_DIALOG
        })

      # Escape the path for JavaScript
      safe_master_path = current_master.gsub("\\", "\\\\\\\\").gsub("\"", "\\\"")

      # Use the dialogs module for HTML
      dialog.set_html(Dialogs.settings_dialog_html(safe_master_path, disable_auto_prompts, skip_threshold_minutes))
      
      dialog.add_action_callback("browse_master") do |action_context|
        path = UI.savepanel("Select Master File Location", "", "*.skp")
        if path
          # Send the path back to the dialog
          js = "document.getElementById('master_path').value = '#{path.gsub("\\", "\\\\\\\\")}';";
          dialog.execute_script(js)
        end
      end
      
      dialog.add_action_callback("save_settings") do |action_context, json_data|
        require 'json'
        data = JSON.parse(json_data)
        
        set_setting(model, 'master_file_path', data['masterPath'])
        set_setting(model, 'disable_auto_prompts', data['disableAutoPrompts'])
        set_setting(model, 'skip_threshold_minutes', data['skipThresholdMinutes'])
        
        UI.messagebox("Settings saved successfully!")
        dialog.close
      end

      dialog.add_action_callback("cancel") do |action_context|
        dialog.close
      end

      dialog.center
      dialog.show
    end

    # Pop up the dialog to ask what changed
    def self.prompt_for_log(model, force: false)
      log_path = get_log_path(model)
      return unless log_path # Safety check

      # Skip if auto-prompts are disabled (unless forced by manual trigger)
      return unless force || !get_setting(model, 'disable_auto_prompts', false)
      
      # Time-based filtering (unless forced)
      unless force
        last_prompt = get_setting(model, 'last_prompt_time', nil)
        threshold_minutes = get_setting(model, 'skip_threshold_minutes', 5)
        
        if last_prompt
          begin
            elapsed_minutes = (Time.now - Time.parse(last_prompt)) / 60.0
            if elapsed_minutes < threshold_minutes
              return # Skip auto-save
            end
          rescue => e
            # If parsing fails, continue with prompt
            puts "Error parsing last_prompt_time: #{e.message}"
          end
        end
      end
      
      # Store current time before showing dialog
      set_setting(model, 'last_prompt_time', Time.now.to_s)

      # Get current master file path from settings
      master_path = get_setting(model, 'master_file_path', '')
      push_to_master_checked = get_setting(model, 'push_to_master_enabled', false)
      
      # Escape master path for JavaScript
      safe_master_path = master_path.gsub("\\", "\\\\\\\\").gsub("\"", "\\\"")

      dialog = UI::HtmlDialog.new(
        {
          :dialog_title => "Commit Changes",
          :preferences_key => "com.yoo.projectchangelog.commit_log_input",
          :scrollable => false,
          :resizable => true,
          :width => 450,
          :height => 350,
          :style => UI::HtmlDialog::STYLE_DIALOG
        })

      # Use the dialogs module for HTML
      dialog.set_html(Dialogs.commit_dialog_html(safe_master_path, push_to_master_checked))
      
      dialog.add_action_callback("browse_master") do |action_context|
        path = UI.savepanel("Select Master File Location", "", "*.skp")
        if path
          # Send the path back to the dialog
          js = "document.getElementById('master_path').value = '#{path.gsub("\\", "\\\\\\\\")}';";
          dialog.execute_script(js)
        end
      end
      
      dialog.add_action_callback("open_settings") do |action_context|
        dialog.close
        open_settings_dialog
      end
      
      dialog.add_action_callback("submit_log") do |action_context, json_data|
        require 'json'
        data = JSON.parse(json_data)
        
        timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
        username = ENV['USERNAME'] || ENV['USER'] || 'Unknown'
        
        # Write CSV entry using our helper
        File.open(log_path, 'a') do |file|
          row = [timestamp, username, data['message']]
          csv_line = row.map { |val| CSVHelper.escape_csv_value(val) }.join(',')
          file.puts(csv_line)
        end
        puts "Log updated at #{log_path}"
        
        # Save settings
        set_setting(model, 'push_to_master_enabled', data['pushToMaster'])
        if !data['masterPath'].empty?
          set_setting(model, 'master_file_path', data['masterPath'])
        end
        
        # Push to master if requested
        if data['pushToMaster'] && !data['masterPath'].empty?
          source_path = model.path
          if push_to_master(source_path, data['masterPath'])
            UI.messagebox("Changes logged and pushed to master successfully!")
          else
            UI.messagebox("Changes logged, but push to master failed. Check the console for details.")
          end
        end
        
        dialog.close
      end

      dialog.add_action_callback("cancel") do |action_context|
        dialog.close
      end

      dialog.center
      dialog.show
    end

    # Viewer for the log
    def self.open_log_viewer
      model = Sketchup.active_model
      log_path = get_log_path(model)

      unless log_path && File.exist?(log_path)
        UI.messagebox("No log file found. Save the model to start a log.")
        return
      end

      # Read and parse CSV data using our helper
      rows = []
      File.open(log_path, 'r') do |file|
        file.each_line do |line|
          line.strip!
          rows << CSVHelper.parse_csv_line(line) unless line.empty?
        end
      end

      dialog = UI::HtmlDialog.new(
        {
          :dialog_title => "Project History",
          :preferences_key => "com.yoo.projectchangelog.log_viewer",
          :resizable => true,
          :width => 800,
          :height => 600,
          :style => UI::HtmlDialog::STYLE_WINDOW
        })

      # Use the dialogs module for HTML
      dialog.set_html(Dialogs.log_viewer_dialog_html(rows, File.basename(model.path)))

      dialog.center
      dialog.show
    end

    # ------------------------------------------------------------------------
    # INITIALIZATION
    # ------------------------------------------------------------------------
    unless file_loaded?(__FILE__)
      # Add Menu Items
      menu = UI.menu('Plugins')
      submenu = menu.add_submenu('Project Change Log')
      submenu.add_item('View History') {
        self.open_log_viewer
      }
      submenu.add_item('Log Changes Now') {
        model = Sketchup.active_model
        if model.path.empty?
          UI.messagebox("Please save the model first before logging changes.")
        else
          self.prompt_for_log(model, force: true)
        end
      }
      submenu.add_item('Settings...') {
        self.open_settings_dialog
      }

      # Create singleton observers
      @app_observer ||= MyAppObserver.new
      @model_observer ||= MyModelObserver.new
      
      # Attach the AppObserver to watch for application events
      Sketchup.add_observer(@app_observer)

      # Attach ModelObserver to the currently active model immediately
      # (Because onNewModel/onOpenModel won't fire for the model already open when SketchUp starts)
      attach_model_observer(Sketchup.active_model)

      file_loaded(__FILE__)
    end

  end
end