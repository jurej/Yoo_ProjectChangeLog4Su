# Open SketchUp Framework - HtmlUi module
# Namespaced copy of open-sketchup-framework/src/open_sketchup_html_dialog.rb (v0.2.1).
# Each plugin carries its own copy - do not load as a shared library.

module Yoo_ProjectChangeLog4Su
  module ProjectChangeLog
    module HtmlUi
      require 'json'

      MODUS_VERSION    = '1.19.1'.freeze
      MODUS_CDN        = 'https://cdn.jsdelivr.net/npm/@trimble-oss/moduswebcomponents'.freeze
      MIN_CEF_VERSION  = 88 # SketchUp 2021.1

      # =========================================================================
      # SUPPORT CHECK
      # =========================================================================

      # True when this SketchUp version can run Modus Web Components in
      # UI::HtmlDialog (ES modules + custom elements need CEF 88 / SU 2021.1+).
      # When false, fall back to Helpers.input_dialog / UI.messagebox.
      def self.supported?
        return false unless defined?(UI::HtmlDialog)

        if defined?(UI::HtmlDialog::CEF_VERSION)
          UI::HtmlDialog::CEF_VERSION.to_i >= MIN_CEF_VERSION
        else
          Sketchup.version.to_f >= 21.1
        end
      end

      # =========================================================================
      # MODUS BOOTSTRAP SNIPPETS
      # =========================================================================

      # Canonical <head> snippet that loads Modus from jsDelivr (version pinned —
      # do NOT use @latest). Paste inside <head> of your dialog HTML, or use the
      # ready-made shell in templates/modus_plugin/html/dialog.html.
      #
      # For offline plugins, vendor the files instead — see
      # templates/modus_plugin/html/vendor/README.md.
      def self.modus_head(version: MODUS_VERSION)
        base = "#{MODUS_CDN}@#{version}"
        <<~HTML
          <link rel="stylesheet" href="#{base}/modus-wc-styles.css" />
          <link rel="stylesheet" href="#{base}/modus-icons.css" />
          <script type="module" src="#{base}/modus-wc/modus-wc.esm.js"><\/script>
        HTML
      end

      # Canonical inline theme bootstrap. Put inside <head> BEFORE the Modus
      # loader so data-theme/data-mode/class are correct on first paint (no FOUC).
      #
      # mode: :system (resolve via prefers-color-scheme), :light, or :dark.
      # Also exposes window.__modusSetTheme(mode) for runtime switching.
      def self.theme_bootstrap_script(mode: :system)
        pref = mode.to_s
        <<~JS
          (function () {
            var pref = "#{pref}";
            function resolve(m) {
              return m === "system"
                ? (window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
                : m;
            }
            window.__modusSetTheme = function (m) {
              var mode = resolve(m || pref);
              var el = document.documentElement;
              el.setAttribute("data-theme", mode === "dark" ? "modus-modern-dark" : "modus-modern-light");
              el.setAttribute("data-mode", mode);
              el.classList.remove("light", "dark");
              el.classList.add(mode);
              try { localStorage.setItem("modus-theme-config", JSON.stringify({ theme: "modus-modern", mode: mode })); } catch (e) {}
            };
            window.__modusSetTheme(pref);
          })();
        JS
      end

      # =========================================================================
      # SHOWING DIALOGS
      # =========================================================================

      # Create and show a UI::HtmlDialog that loads an HTML file from your
      # plugin's support folder.
      #
      #   dialog = HtmlUi.show(html_file: "dialog.html", title: "Extrude Faces")
      #
      # Parameters:
      #   html_file:       Filename (or relative path) inside html_dir
      #   html_dir:        Defaults to "<support folder>/html"
      #   title:           Window title
      #   width, height:   Dialog size (content size on SU 2021.1+)
      #   resizable:       Allow resize (default true)
      #   modal:           Use show_modal instead of show (default false)
      #   preferences_key: UI::HtmlDialog position key (auto-derived from title)
      #   on_closed:       Optional Proc called when the user closes the dialog
      #
      # The dialog is retained internally until closed — do NOT rely on a local
      # variable to keep it alive (GC collects unreferenced dialogs).
      def self.show(html_file:, title:, width: 420, height: 520,
                    resizable: true, modal: false, html_dir: nil,
                    preferences_key: nil, on_closed: nil)
        options = {
          dialog_title: title,
          preferences_key: preferences_key || "OSF_Dialog_#{title.gsub(/\W/, '_')}",
          width: width,
          height: height,
          resizable: resizable,
          style: UI::HtmlDialog::STYLE_DIALOG
        }
        # use_content_size exists on SU 2021.1+ (same floor as Modus support)
        options[:use_content_size] = true if supported?

        dialog = UI::HtmlDialog.new(options)
        dialog.set_file(File.join(html_dir || File.join(SUPPORT_DIR, 'html'), html_file))

        retain(dialog)
        dialog.set_on_closed do
          release(dialog)
          on_closed.call(dialog) if on_closed
        end

        modal ? dialog.show_modal : dialog.show
        dialog
      end

      # =========================================================================
      # RUBY <-> JS BRIDGE
      # =========================================================================

      # Register a JS -> Ruby callback. In JS, call:
      #
      #   callRuby("submit_form", { name: "wall", height: 3000 })
      #
      # On the Ruby side:
      #
      #   HtmlUi.on(dialog, "submit_form") do |ctx|
      #     values = ctx.payload        # decoded JSON Hash (or first raw arg)
      #     # ... do work ...
      #     ctx.reply(ok: true)         # resolves the callRuby Promise in JS
      #   rescue => e
      #     ctx.reply_error(e.message)  # rejects the Promise
      #   end
      #
      # Exceptions inside the block are logged to the Ruby console and reported
      # back to JS instead of crashing SketchUp.
      def self.on(dialog, name, &block)
        dialog.add_action_callback(name) do |_action_ctx, *args|
          ctx = CallbackContext.new(dialog, decode_payload(args.first))
          begin
            block.call(ctx)
          rescue StandardError => e
            puts "Open SketchUp HTML UI: action '#{name}' failed: #{e.message}"
            puts e.backtrace.join("\n") if e.backtrace
            ctx.reply_error(e.message)
          end
        end
      end

      # Call a JS function in the dialog with JSON-serializable arguments.
      #
      #   HtmlUi.call_js(dialog, "setFaceCount", 42)
      def self.call_js(dialog, fn_name, *args)
        js_args = args.map { |a| a.to_json }.join(', ')
        dialog.execute_script("#{fn_name}(#{js_args})")
      end

      # Lightweight context object passed to HtmlUi.on blocks.
      class CallbackContext
        attr_reader :dialog, :payload

        def initialize(dialog, payload)
          @dialog = dialog
          @payload = payload
        end

        # Resolve the matching callRuby() Promise in JS.
        def reply(data = {})
          send_reply(true, data)
        end

        # Reject the matching callRuby() Promise in JS.
        def reply_error(message)
          send_reply(false, { 'message' => message.to_s })
        end

        private

        # Deliberately no reference to the outer module name here — this file is
        # meant to be renamed when copied into a plugin namespace.
        def send_reply(success, data)
          req_id = @payload.is_a?(Hash) ? @payload['_reqId'].to_i : 0
          js_args = [req_id, success, data].map { |a| a.to_json }.join(', ')
          @dialog.execute_script("__rubyReply(#{js_args})")
        end
      end

      # =========================================================================
      # INTERNALS
      # =========================================================================

      # Parse the first callback argument: JSON string -> Hash/Array, otherwise
      # pass through as-is (SketchUp already converts numbers/booleans).
      def self.decode_payload(arg)
        return nil if arg.nil?

        if arg.is_a?(String) && arg.strip.start_with?('{', '[')
          JSON.parse(arg)
        else
          arg
        end
      rescue JSON::ParserError
        arg
      end
      private_class_method :decode_payload

      # Keep a strong reference to each open dialog (known SketchUp gotcha:
      # unreferenced dialogs get garbage-collected while still on screen).
      # compare_by_identity avoids object_id reuse collisions.
      def self.retain(dialog)
        @_dialogs ||= {}.compare_by_identity
        @_dialogs[dialog] = dialog
      end
      private_class_method :retain

      def self.release(dialog)
        @_dialogs&.delete(dialog)
      end
      private_class_method :release
    end
  end
end
