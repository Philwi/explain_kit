// For hosts that build markup in JavaScript (canvas readouts, tiles): the same
// trigger explain_term renders on the server. Clicks are handled by the page's
// explain controller through delegation, nothing to wire up.
const ESCAPES = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }
const esc = (value) => String(value).replace(/[&<>"']/g, (c) => ESCAPES[c])

// labelHtml must already be escaped HTML.
// `icon: true` keeps the content plain and appends a small "?" button, like explain_term(icon: true);
// `label` is then the button's accessible name (localised by the host, e.g. "What is Score?").
export function explainTriggerHTML(key, labelHtml, { bands, icon, label } = {}) {
  const attrs = bands ? ` data-explain-bands="${esc(bands)}"` : ""
  if (icon) {
    return `<span class="explain-term explain-term--icon">${labelHtml}<button type="button" class="explain-term__trigger" data-explain-key="${esc(key)}"${attrs} aria-label="${esc(label || "?")}" aria-expanded="false" aria-controls="explain-popover" aria-haspopup="dialog"><span aria-hidden="true">?</span></button></span>`
  }
  return `<button type="button" class="explain-term explain-term--wrap" data-explain-key="${esc(key)}"${attrs} aria-expanded="false" aria-controls="explain-popover" aria-haspopup="dialog">${labelHtml}</button>`
}

export function explainTrigger(key, text, options) {
  const template = document.createElement("template")
  template.innerHTML = explainTriggerHTML(key, esc(text), options)
  return template.content.firstElementChild
}
