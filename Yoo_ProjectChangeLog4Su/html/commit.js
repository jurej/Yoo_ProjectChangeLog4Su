// Commit dialog wiring - see bridge.js for the callRuby contract.

"use strict";

const state = { message: "", pushToMaster: false, masterPath: "" };

async function init() {
  await modusReady([
    "modus-wc-card",
    "modus-wc-typography",
    "modus-wc-textarea",
    "modus-wc-checkbox",
    "modus-wc-text-input",
    "modus-wc-button",
    "modus-wc-alert",
    "modus-wc-icon",
  ]);

  // Initial state from Ruby (mocked {dev:true} in a plain browser).
  try {
    const init = await callRuby("commit_ready", {});
    if (init && !init.dev) {
      state.masterPath = init.masterPath || "";
      state.pushToMaster = Boolean(init.pushToMaster);
      document.getElementById("master_path").value = state.masterPath;
      document.getElementById("push_to_master").value = state.pushToMaster;
    }
  } catch (e) {
    // Keep defaults when the bridge is unavailable.
  }

  document.getElementById("msg").addEventListener("inputChange", (e) => {
    state.message = readInputString(e);
  });
  document.getElementById("master_path").addEventListener("inputChange", (e) => {
    state.masterPath = readInputString(e);
  });
  document.getElementById("push_to_master").addEventListener("inputChange", (e) => {
    state.pushToMaster = readInputChecked(e);
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

  document.getElementById("btn-settings").addEventListener("buttonClick", () => {
    callRuby("open_settings", {});
  });

  document.getElementById("btn-cancel").addEventListener("buttonClick", () => {
    callRuby("cancel", {});
  });

  document.getElementById("btn-submit").addEventListener("buttonClick", async () => {
    try {
      const res = await callRuby("submit_log", {
        message: state.message,
        pushToMaster: state.pushToMaster,
        masterPath: state.masterPath,
      });
      if (res && res.success === false) {
        showResult("result", "error", res.message || "Push to master failed.");
        return;
      }
      showResult("result", "success", (res && res.message) || "Changes logged.");
      // Brief confirmation, then close through the normal cancel path.
      setTimeout(() => callRuby("cancel", {}), 1200);
    } catch (err) {
      showResult("result", "error", err.message);
    }
  });
}

init();
