# Open SketchUp Framework - UpdateChecker module
# Namespaced copy of open-sketchup-framework/src/open_sketchup_update_checker.rb (v0.2.1).
# Each plugin carries its own copy - do not load as a shared library.

module Yoo_ProjectChangeLog4Su
  module ProjectChangeLog
    module UpdateChecker
      # Check for updates asynchronously. Safe to call at plugin load time.
      # Does NOT download or install anything — only notifies the user.
      #
      # Parameters:
      #   extension:       SketchupExtension object (required for UI::Notification)
      #   current_version: String, e.g. "1.2.0"
      #   version_url:     URL to a JSON file: { "version": "x.y.z" }
      #   download_url:    URL to open in browser when user accepts (optional;
      #                    can also be provided in the JSON as "download_url")
      #   check_interval:  Seconds between checks (default: 86400 = 24 hours)
      #   preferences_key: Section name for Sketchup.write_default (auto-derived
      #                    from extension name if omitted)
      #
      # The hosted version.json format:
      #   {
      #     "version": "1.3.0",
      #     "download_url": "https://extensions.sketchup.com/extension/abc123",
      #     "release_notes": "Fixed crash on large models"
      #   }
      #   Only "version" is required.
      #
      # Usage:
      #   UpdateChecker.check_for_update(
      #     extension: EXTENSION,
      #     current_version: "1.0.0",
      #     version_url: "https://raw.githubusercontent.com/you/repo/main/version.json",
      #     download_url: "https://extensions.sketchup.com/extension/YOUR_ID"
      #   )
      #
      def self.check_for_update(extension:, current_version:, version_url:,
                                 download_url: nil, check_interval: 86400,
                                 preferences_key: nil)
        # Require SU2017+ for Sketchup::Http and UI::Notification
        return unless defined?(Sketchup::Http::Request)
        return unless defined?(UI::Notification)

        pref_key = preferences_key || "OSF_Update_#{extension.name.gsub(/\W/, '_')}"

        # Check cooldown — skip if checked recently
        last_check = Sketchup.read_default(pref_key, "last_check", 0).to_i
        return if (Time.now.to_i - last_check) < check_interval

        # Delay the check so it doesn't slow down SketchUp startup
        UI.start_timer(2, false) do
          perform_check(extension, current_version, version_url, download_url, pref_key)
        end
      end

      # -------------------------------------------------------------------------
      # Private implementation
      # -------------------------------------------------------------------------

      # Perform the async HTTP check. Separated for clarity.
      def self.perform_check(extension, current_version, version_url, download_url, pref_key)
        request = Sketchup::Http::Request.new(version_url, Sketchup::Http::GET)

        request.start do |_req, response|
          # Record that we checked, regardless of outcome
          Sketchup.write_default(pref_key, "last_check", Time.now.to_i)

          next unless response.status_code == 200

          begin
            require 'json'
            data = JSON.parse(response.body)
          rescue => _e
            next # Malformed JSON — fail silently
          end

          remote_version = data["version"].to_s.strip
          next if remote_version.empty?
          next unless newer?(remote_version, current_version)

          # Determine the download URL (JSON value takes priority over parameter)
          url = data["download_url"] || download_url
          notes = data["release_notes"].to_s

          show_notification(extension, remote_version, url, notes)
        end

        # Prevent garbage collection of the request (known SketchUp gotcha:
        # if no reference is kept, the request is silently aborted).
        @_request = request
      rescue => e
        puts "Open SketchUp Update Checker: #{e.message}"
      end
      private_class_method :perform_check

      # Compare two semver strings. Returns true if remote is newer.
      def self.newer?(remote, current)
        remote_parts = version_tuple(remote)
        current_parts = version_tuple(current)
        (remote_parts <=> current_parts) == 1
      end
      private_class_method :newer?

      # Parse "1.2.3" into [1, 2, 3]. Handles missing parts ("1.2" -> [1, 2, 0]).
      def self.version_tuple(version_string)
        parts = version_string.to_s.split(".").map(&:to_i)
        parts.fill(0, parts.length...3)
      end
      private_class_method :version_tuple

      # Show a native notification about the available update.
      def self.show_notification(extension, remote_version, url, notes)
        message = "#{extension.name} v#{remote_version} is available."
        message += "\n#{notes}" unless notes.empty?

        notification = UI::Notification.new(extension, message)

        if url && !url.empty?
          notification.on_accept("Update") { UI.openURL(url) }
        end
        notification.on_dismiss("Later") {}

        notification.show

        # Prevent GC of the notification (known issue prior to SU2021.1)
        @_notification = notification
      end
      private_class_method :show_notification
    end
  end
end
