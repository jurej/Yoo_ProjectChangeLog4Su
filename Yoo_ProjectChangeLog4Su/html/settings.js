// Settings dialog wiring - see bridge.js for the callRuby contract.

"use strict";

const state = { masterPath: "", enableAutoPrompts: false, skipThresholdMinutes: 5 };

async function init() {
  await modusReady([
    "modus-wc-card",
    "modus-wc-typography",
    "modus-wc-icon",
    "modus-wc-checkbox",
    "modus-wc-number-input",
    "modus-wc-text-input",
    "modus-wc-button",
    "modus-wc-alert",
  ]);

  // Initial state from Ruby (mocked {dev:true} in a plain browser).
  try {
    const init = await callRuby("settings_ready", {});
    if (init && !init.dev) {
      state.masterPath = init.masterPath || "";
      state.enableAutoPrompts = Boolean(init.enableAutoPrompts);
      state.skipThresholdMinutes = Number(init.skipThresholdMinutes);
      if (isNaN(state.skipThresholdMinutes)) state.skipThresholdMinutes = 5;

      document.getElementById("master_path").value = state.masterPath;
      document.getElementById("enable_auto_prompts").value = state.enableAutoPrompts;
      document.getElementById("skip_threshold_minutes").value =
        String(state.skipThresholdMinutes);
    }
  } catch (e) {
    // Keep defaults when the bridge is unavailable.
  }

  document.getElementById("master_path").addEventListener("inputChange", (e) => {
    state.masterPath = readInputString(e);
  });
  document.getElementById("enable_auto_prompts").addEventListener("inputChange", (e) => {
    state.enableAutoPrompts = readInputChecked(e);
  });
  document.getElementById("skip_threshold_minutes").addEventListener("inputChange", (e) => {
    state.skipThresholdMinutes = Number(readInputString(e));
  });

  document.getElementById("btn-browse").addEventListener("buttonClick", async () => {
    try {
      const res = await callRuby("browse_master", {});
      if (res && res.path) {
        state.masterPath = res.path;
        document.getElementById("master_path").value = res.path;
      }
    } catch (e) {
      // User cancelled the save panel - nothing to do.
    }
  });

  document.getElementById("btn-cancel").addEventListener("buttonClick", () => {
    callRuby("cancel", {});
  });

  document.getElementById("btn-save").addEventListener("buttonClick", async () => {
    // Clamp the threshold between 0 and 60 (0 disables skipping).
    let threshold = Number(state.skipThresholdMinutes);
    if (isNaN(threshold) || threshold < 0) threshold = 5;
    threshold = Math.max(0, Math.min(60, Math.round(threshold)));

    try {
      const res = await callRuby("save_settings", {
        masterPath: state.masterPath,
        enableAutoPrompts: state.enableAutoPrompts,
        skipThresholdMinutes: threshold,
      });
      if (res && res.success === false) {
        showResult("result", "error", res.message || "Settings could not be saved.");
        return;
      }
      showResult("result", "success", "Settings saved.");
      setTimeout(() => callRuby("cancel", {}), 1200);
    } catch (err) {
      showResult("result", "error", err.message);
    }
  });
}

init();
