// History viewer wiring - see bridge.js for the callRuby contract.

"use strict";

async function init() {
  await modusReady([
    "modus-wc-card",
    "modus-wc-typography",
    "modus-wc-checkbox",
    "modus-wc-table",
    "modus-wc-alert",
  ]);

  const table = document.getElementById("log-table");
  table.columns = [
    { id: "timestamp", header: "Timestamp", accessor: "timestamp", width: "170px" },
    { id: "user", header: "User", accessor: "user", width: "120px" },
    { id: "message", header: "Message", accessor: "message" },
  ];
  table.zebra = true;
  table.hover = true;
  table.sortable = true;
  table.paginated = true;
  table.pageSizeOptions = [10, 15, 25];

  // Table data and current settings from Ruby (mocked {dev:true} in a
  // plain browser - show sample rows so the UI can be exercised).
  try {
    const init = await callRuby("history_ready", {});
    if (init && init.dev) {
      table.data = [
        { timestamp: "2026-11-24 09:15:23", user: "DevUser", message: "- Sample entry\n- Second line" },
        { timestamp: "2026-11-23 15:20:33", user: "DevUser", message: "- Earlier sample entry" },
      ];
    } else if (init) {
      document.getElementById("history-title").label =
        "Project history (" + (init.fileName || "") + ")";
      document.getElementById("enable_auto_prompts").value = Boolean(init.autoPrompts);
      table.data = init.rows || [];
      if (!init.rows || init.rows.length === 0) {
        table.hidden = true;
        document.getElementById("empty-state").hidden = false;
      }
    }
  } catch (e) {
    showResult("empty-state", "error", e.message);
    document.getElementById("empty-state").hidden = false;
  }

  document.getElementById("enable_auto_prompts").addEventListener("inputChange", (e) => {
    callRuby("update_auto_prompts", { enabled: readInputChecked(e) });
  });
}

init();
