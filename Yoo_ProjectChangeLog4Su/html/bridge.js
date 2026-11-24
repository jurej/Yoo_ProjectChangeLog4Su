// Ruby <-> JS bridge + shared helpers for SketchUp HtmlDialog.
//
// Ruby side calls  HtmlUi.on(dialog, "name") { |ctx| ... } which registers
// window.sketchup.<name>. JS calls back via callRuby(action, payload) which
// returns a Promise; Ruby resolves it with ctx.reply(data) or rejects it
// with ctx.reply_error(message) -> window.__rubyReply(reqId, ok, data).
//
// Chrome dev loop: when window.sketchup is missing (file opened in a normal
// browser), callRuby resolves a mock so the UI can be exercised without
// SketchUp.

"use strict";

let _reqId = 0;
const _pending = new Map();

function callRuby(action, payload = {}) {
  return new Promise((resolve, reject) => {
    if (!window.sketchup || typeof window.sketchup[action] !== "function") {
      console.warn("[dev] window.sketchup." + action + " is not available - mocked response");
      resolve({ dev: true });
      return;
    }
    const reqId = ++_reqId;
    _pending.set(reqId, { resolve, reject });
    window.sketchup[action](JSON.stringify({ ...payload, _reqId: reqId }));
  });
}

// Called from Ruby via execute_script - matches CallbackContext#send_reply.
window.__rubyReply = function (reqId, ok, payload) {
  const entry = _pending.get(reqId);
  if (!entry) return;
  _pending.delete(reqId);
  if (ok) entry.resolve(payload);
  else entry.reject(new Error((payload && payload.message) || "Ruby error"));
};

// ---------------------------------------------------------------------------
// Modus 2.x event contract:
//   text/textarea/number/select : inputChange -> e.detail.target.value
//   checkbox/switch             : inputChange -> e.detail.target.checked
//   buttons                     : buttonClick
// ---------------------------------------------------------------------------

function readInputString(e) {
  const t = e.detail && e.detail.target;
  return t ? String(t.value ?? "") : "";
}

function readInputChecked(e) {
  const t = e.detail && e.detail.target;
  return Boolean(t && t.checked);
}

// Reveal the page once every Modus tag used on it is defined (FOUC guard).
async function modusReady(tags) {
  await Promise.all(tags.map((t) => customElements.whenDefined(t)));
  document.body.classList.add("modus-ready");
}

function showResult(boxId, kind, message) {
  const box = document.getElementById(boxId);
  box.hidden = false;
  box.innerHTML =
    `<modus-wc-alert variant="${kind}" dismissible>` +
    `${message}</modus-wc-alert>`;
}
