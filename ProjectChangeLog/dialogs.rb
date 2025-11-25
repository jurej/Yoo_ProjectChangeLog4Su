# Copyright:: Copyright 2024
# License:: The MIT License (MIT)

module ProjectChangeLog4Su
  module Dialogs

    # Shared Trimble Modus-based stylesheet for all dialogs
    SHARED_STYLES = <<-CSS
      /* Trimble Modus Design System for SketchUp */
      * { box-sizing: border-box; }
      
      body {
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        font-size: 14px;
        line-height: 1.5;
        color: #252a2e;
        background: #ffffff;
        padding: 16px;
        margin: 0;
      }

      h3 {
        font-size: 18px;
        font-weight: 600;
        color: #252a2e;
        margin: 0 0 16px 0;
      }

      label {
        display: block;
        font-weight: 500;
        color: #464b52;
        margin-bottom: 6px;
        font-size: 13px;
      }

      input[type="text"] {
        width: 100%;
        padding: 8px 12px;
        border: 1px solid #cbcdd6;
        border-radius: 4px;
        font-size: 14px;
        font-family: inherit;
        background: #ffffff;
        margin-bottom: 12px;
        transition: border-color 0.2s;
      }

      input[type="text"]:focus {
        outline: none;
        border-color: #0063a3;
        box-shadow: 0 0 0 3px rgba(0, 99, 163, 0.1);
      }

      input[type="checkbox"] {
        margin-right: 8px;
        width: 16px;
        height: 16px;
        vertical-align: middle;
      }

      textarea {
        width: 100%;
        padding: 8px 12px;
        border: 1px solid #cbcdd6;
        border-radius: 4px;
        font-size: 14px;
        font-family: inherit;
        resize: vertical;
        min-height: 80px;
        margin-bottom: 12px;
        transition: border-color 0.2s;
      }

      textarea:focus {
        outline: none;
        border-color: #0063a3;
        box-shadow: 0 0 0 3px rgba(0, 99, 163, 0.1);
      }

      button {
        padding: 8px 16px;
        font-size: 14px;
        font-weight: 500;
        font-family: inherit;
        border: none;
        border-radius: 4px;
        cursor: pointer;
        transition: all 0.2s;
        line-height: 1.5;
      }

      button.primary {
        background: #0063a3;
        color: #ffffff;
      }

      button.primary:hover {
        background: #004f82;
      }

      button.secondary {
        background: #6a7075;
        color: #ffffff;
      }

      button.secondary:hover {
        background: #545b60;
      }

      button.tertiary {
        background: #e0e1e9;
        color: #171c1e;
      }

      button.tertiary:hover {
        background: #cbcdd6;
      }

      button:active {
        transform: translateY(1px);
      }

      small {
        color: #6a7075;
        font-size: 12px;
        line-height: 1.4;
      }

      .button-row {
        display: flex;
        justify-content: flex-end;
        gap: 8px;
        margin-top: 16px;
      }

      .path-row {
        display: flex;
        gap: 8px;
        margin-bottom: 12px;
      }

      .path-row input {
        flex: 1;
        margin-bottom: 0;
      }

      .path-row button {
        white-space: nowrap;
      }

      .section {
        border: 1px solid #e0e1e9;
        border-radius: 4px;
        padding: 12px;
        margin: 12px 0;
        background: #f8f9fa;
      }

      .section label {
        margin: 0 0 8px 0;
      }
    CSS

    # Settings Dialog HTML
    def self.settings_dialog_html(safe_master_path)
      <<-HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>#{SHARED_STYLES}</style>
        </head>
        <body>
          <h3>Master File Settings</h3>
          <label for="master_path">Master File Path:</label>
          <div class="path-row">
            <input type="text" id="master_path" placeholder="C:\\\\Projects\\\\MyModel_MASTER.skp" value="#{safe_master_path}">
            <button class="secondary" onclick="browseMaster()">Browse...</button>
          </div>
          <small>This is the path where your master file will be saved when you "Push to Master".</small>
          
          <div class="button-row">
            <button class="tertiary" onclick="window.location='skp:cancel'">Cancel</button>
            <button class="primary" onclick="saveSettings()">Save Settings</button>
          </div>
          <script>
            function browseMaster() {
              window.location = 'skp:browse_master';
            }
            function saveSettings() {
              var path = document.getElementById('master_path').value;
              window.location = 'skp:save_settings@' + encodeURIComponent(path);
            }
          </script>
        </body>
        </html>
      HTML
    end

    # Commit Changes Dialog HTML
    def self.commit_dialog_html(safe_master_path, push_to_master_checked)
      checked_attr = push_to_master_checked ? 'checked' : ''
      <<-HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>#{SHARED_STYLES}</style>
        </head>
        <body>
          <h3>What changed in this version?</h3>
          <textarea id="msg" placeholder="- Add description of changes"></textarea>
          
          <div class="section">
            <label>
              <input type="checkbox" id="push_to_master" #{checked_attr}> 
              Push to Master (like git push)
            </label>
            <div class="path-row">
              <input type="text" id="master_path" placeholder="C:\\\\Projects\\\\MyModel_MASTER.skp" value="#{safe_master_path}">
              <button class="secondary" onclick="browseMaster()">Browse...</button>
              <button class="secondary" onclick="openSettings()">Settings</button>
            </div>
            <small>Master file will be overwritten to maintain the same filename (important for Layout links)</small>
          </div>
          
          <div class="button-row">
            <button class="tertiary" onclick="window.location='skp:cancel'">Skip</button>
            <button class="primary" onclick="submitLog()">Log Change</button>
          </div>
          <script>
            function submitLog() {
              var txt = document.getElementById('msg').value;
              var pushToMaster = document.getElementById('push_to_master').checked;
              var masterPath = document.getElementById('master_path').value;
              var data = JSON.stringify({
                message: txt,
                pushToMaster: pushToMaster,
                masterPath: masterPath
              });
              window.location = 'skp:submit_log@' + encodeURIComponent(data);
            }
            function browseMaster() {
              window.location = 'skp:browse_master';
            }
            function openSettings() {
              window.location = 'skp:open_settings';
            }
          </script>
        </body>
        </html>
      HTML
    end

    # Log Viewer Dialog HTML
    def self.log_viewer_dialog_html(safe_content, basename)
      <<-HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            #{SHARED_STYLES}
            body {
              display: flex;
              flex-direction: column;
              height: 95vh;
              padding: 16px;
            }
            h3 {
              margin: 0 0 12px 0;
              flex-shrink: 0;
            }
            textarea {
              flex: 1;
              font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
              font-size: 13px;
              margin-bottom: 12px;
            }
            .button-row {
              flex-shrink: 0;
            }
          </style>
        </head>
        <body>
          <h3>Project History (#{basename})</h3>
          <textarea id="full_log">#{safe_content}</textarea>
          <div class="button-row">
            <button class="primary" onclick="saveChanges()">Save Edits</button>
          </div>
          <script>
            function saveChanges() {
              var txt = document.getElementById('full_log').value;
              sketchup.save_full_log(txt);
            }
          </script>
        </body>
        </html>
      HTML
    end

  end
end
