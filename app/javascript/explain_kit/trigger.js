// For hosts that build markup in JavaScript (canvas readouts, tiles): the same
// trigger explain_term renders on the server. Clicks are handled by the page's
// explain controller through delegation, nothing to wire up.
const ESCAPES = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }
const esc = (value) => String(value).replace(/[&<>"']/g, (c) => ESCAPES[c])

// labelHtml must already be escaped HTML.
export function explainTriggerHTML(key, labelHtml, { bands } = {}) {
  const attrs = bands ? ` data-explain-bands="${esc(bands)}"` : ""
  return `<button type="button" class="explain-term explain-term--wrap" data-explain-key="${esc(key)}"${attrs} aria-expanded="false" aria-controls="explain-popover" aria-haspopup="dialog">${labelHtml}</button>`
}

export function explainTrigger(key, text, options) {
  const template = document.createElement("template")
  template.innerHTML = explainTriggerHTML(key, esc(text), options)
  return template.content.firstElementChild
}
