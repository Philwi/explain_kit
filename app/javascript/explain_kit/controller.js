import { Controller } from "@hotwired/stimulus"

// ExplainKit: one controller per page, mounted by `explain_mount`. Everything is
// event delegation on `document`, so triggers (`[data-explain-key]`) and the nav
// "?" (`[data-explain-page-help]`) can live anywhere, also inside lazy frames.
//
// Persistence of "seen" terms: window.ExplainKitStorage = { read(): string[], write(keys: string[]) }
// overrides the localStorage default (e.g. to store per account on the server).

const SEEN_KEY = "explain_kit:seen"
const FOCUSABLE = "button:not([disabled]), a[href], [tabindex]:not([tabindex='-1'])"
const DESKTOP = "(min-width: 640px)"

const defaultStorage = {
  read() {
    try { return JSON.parse(localStorage.getItem(SEEN_KEY)) || [] } catch { return [] }
  },
  write(keys) {
    try { localStorage.setItem(SEEN_KEY, JSON.stringify(keys)) } catch { /* private mode */ }
  },
}

const storage = () => window.ExplainKitStorage || defaultStorage

export default class extends Controller {
  static targets = ["data", "backdrop", "popover", "title", "short", "long", "how", "howText", "bands", "more", "panel", "list"]
  static values = { glossaryUrl: String }

  connect() {
    const payload = JSON.parse(this.dataTarget.textContent || "{}")
    this.terms = payload.terms || {}
    this.bandSets = payload.bands || {}
    this.opener = null
    this.onClick = (event) => this.handleClick(event)
    this.onKey = (event) => this.handleKey(event)
    this.onFrame = () => this.refreshPageHelp()
    document.addEventListener("click", this.onClick)
    document.addEventListener("keydown", this.onKey)
    document.addEventListener("turbo:frame-load", this.onFrame)
    this.refreshPageHelp()
  }

  disconnect() {
    document.removeEventListener("click", this.onClick)
    document.removeEventListener("keydown", this.onKey)
    document.removeEventListener("turbo:frame-load", this.onFrame)
  }

  handleClick(event) {
    const target = event.target
    if (!(target instanceof Element)) return

    const term = target.closest("[data-explain-key]")
    const help = target.closest("[data-explain-page-help]")
    const jump = target.closest("[data-explain-jump]")
    const tour = target.closest("[data-explain-tour-start]")
    const close = target.closest("[data-explain-close]")

    if (term) return this.consume(event, () => this.openTerm(term))
    if (help) return this.consume(event, () => this.togglePanel(help))
    if (jump) return this.consume(event, () => this.jumpTo(jump.dataset.explainJump))
    if (tour) return this.consume(event, () => this.startTour(Number(tour.dataset.explainTourStart)))
    if (close || target === this.backdropTarget) return this.closeAll({ restoreFocus: true })
    if (!target.closest(".explain-pop, .explain-panel")) this.closeAll({ restoreFocus: false })
  }

  consume(event, fn) {
    event.preventDefault()
    event.stopPropagation()
    fn()
  }

  handleKey(event) {
    if (this.isClosed()) return
    if (event.key === "Escape") {
      event.preventDefault()
      return this.closeAll({ restoreFocus: true })
    }
    if (event.key === "Tab") this.trapFocus(event)
  }

  isClosed() { return this.popoverTarget.hidden && this.panelTarget.hidden }

  // --- term popover -------------------------------------------------------

  async openTerm(trigger) {
    const key = trigger.dataset.explainKey
    const term = await this.termFor(key)
    if (!term) return

    this.closeAll({ restoreFocus: false })
    this.opener = trigger
    trigger.setAttribute("aria-expanded", "true")
    this.theme(trigger)
    this.fill(term, trigger.dataset.explainBands)
    this.show(this.popoverTarget)
    this.position(trigger)
    this.markSeen([key])
  }

  // The surface the trigger sits on decides the look: [data-explain-theme="dial"] on a wrapper.
  theme(trigger) {
    const surface = trigger.closest("[data-explain-theme]")
    if (surface) this.element.dataset.theme = surface.dataset.explainTheme
    else delete this.element.dataset.theme
  }

  async termFor(key) {
    if (this.terms[key]) return this.terms[key]
    try {
      this.remote ||= await fetch(this.glossaryUrlValue, { headers: { Accept: "application/json" } }).then((r) => r.json())
      this.terms = { ...this.remote.terms, ...this.terms }
      this.bandSets = { ...this.remote.bands, ...this.bandSets }
      return this.terms[key]
    } catch {
      return null
    }
  }

  fill(term, bandsKey) {
    this.titleTarget.textContent = term.title
    this.shortTarget.textContent = term.short
    this.toggleText(this.longTarget, term.long)
    this.how.hidden = !term.how
    this.howTextTarget.textContent = term.how || ""
    this.moreTarget.hidden = !term.more_url
    if (term.more_url) this.moreTarget.href = term.more_url
    this.fillBands(bandsKey)
  }

  get how() { return this.howTarget }

  toggleText(el, text) {
    el.textContent = text || ""
    el.hidden = !text
  }

  fillBands(bandsKey) {
    const list = this.bandSets[bandsKey]
    this.bandsTarget.replaceChildren()
    this.bandsTarget.hidden = !list
    if (!list) return
    list.forEach((band) => {
      const li = document.createElement("li")
      li.className = "explain-bands__item"
      li.dataset.bandKey = band.key
      li.innerHTML = '<span class="explain-bands__min"></span><span class="explain-bands__label"></span>'
      li.firstChild.textContent = band.min
      li.lastChild.textContent = band.label
      this.bandsTarget.append(li)
    })
  }

  position(trigger) {
    const el = this.popoverTarget
    el.style.top = el.style.left = el.style.maxHeight = ""
    if (!window.matchMedia(DESKTOP).matches) return

    const rect = trigger.getBoundingClientRect()
    const width = el.offsetWidth
    const left = Math.min(Math.max(8, rect.left), window.innerWidth - width - 8)
    // Below the trigger; above it when there is more room there. Never on top of the trigger:
    // when neither side fits the popover's full height it shrinks (and scrolls) into the room.
    const gap = 8
    const height = el.offsetHeight
    const roomBelow = window.innerHeight - rect.bottom - gap * 2
    const roomAbove = rect.top - gap * 2
    const flip = height > roomBelow && roomAbove > roomBelow
    const room = flip ? roomAbove : roomBelow
    const used = Math.min(height, room)
    if (height > room) el.style.maxHeight = `${Math.max(room, 120)}px`
    const top = flip ? rect.top - gap - used : rect.bottom + gap
    el.style.left = `${left + window.scrollX}px`
    el.style.top = `${top + window.scrollY}px`
  }

  // --- page help ----------------------------------------------------------

  pageKeys() {
    const seen = new Set()
    document.querySelectorAll("[data-explain-key]:not([data-explain-page='false'])").forEach((el) => seen.add(el.dataset.explainKey))
    return [...seen]
  }

  // A host tour (e.g. a coach) is any element with data-explain-tour="Label". It is listed first
  // in the panel and started by clicking that element, hidden or not.
  tours() { return [...document.querySelectorAll("[data-explain-tour]")] }

  refreshPageHelp() {
    const keys = this.pageKeys()
    const unseen = keys.filter((k) => !storage().read().includes(k))
    document.querySelectorAll("[data-explain-page-help]").forEach((button) => {
      button.hidden = keys.length === 0 && this.tours().length === 0
      const dot = button.querySelector("[data-explain-dot]")
      if (dot) dot.hidden = unseen.length === 0
    })
  }

  async togglePanel(button) {
    if (!this.panelTarget.hidden) return this.closeAll({ restoreFocus: true })

    this.closeAll({ restoreFocus: false })
    this.opener = button
    this.theme(button)
    button.setAttribute("aria-expanded", "true")
    const keys = this.pageKeys()
    await Promise.all(keys.map((k) => this.termFor(k)))
    this.listTarget.replaceChildren(
      ...this.tours().map((el, i) => this.tourItem(el.dataset.explainTour, i)),
      ...keys.filter((k) => this.terms[k]).map((k) => this.listItem(k))
    )
    this.show(this.panelTarget)
    this.markSeen(keys)
  }

  tourItem(label, index) {
    const li = document.createElement("li")
    const button = document.createElement("button")
    button.type = "button"
    button.className = "explain-list__item explain-list__item--tour"
    button.dataset.explainTourStart = index
    button.innerHTML = '<strong class="explain-list__title"></strong>'
    button.firstChild.textContent = label
    li.append(button)
    return li
  }

  startTour(index) {
    const el = this.tours()[index]
    this.closeAll({ restoreFocus: false })
    if (el) el.click()
  }

  listItem(key) {
    const term = this.terms[key]
    const li = document.createElement("li")
    const button = document.createElement("button")
    button.type = "button"
    button.className = "explain-list__item"
    button.innerHTML = '<strong class="explain-list__title"></strong><span class="explain-list__short"></span>'
    button.firstChild.textContent = term.title
    // A term whose trigger is not on screen (hidden tab, JS-revealed block) cannot be jumped to:
    // list it disabled with a hint instead of a dead tap.
    if (this.visibleTrigger(key)) {
      button.dataset.explainJump = key
      button.lastChild.textContent = term.short
    } else {
      button.disabled = true
      button.classList.add("explain-list__item--off")
      button.lastChild.textContent = this.listTarget.dataset.hiddenHint || term.short
    }
    li.append(button)
    return li
  }

  visibleTrigger(key) {
    return [...document.querySelectorAll("[data-explain-key]")]
      .filter((e) => e.dataset.explainKey === key)
      .find((e) => e.getClientRects().length > 0)
  }

  jumpTo(key) {
    const el = this.visibleTrigger(key)
    this.closeAll({ restoreFocus: false })
    if (!el) return

    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    el.scrollIntoView({ block: "center", behavior: reduce ? "auto" : "smooth" })
    el.focus({ preventScroll: true })
    const target = el.closest(".explain-term") || el
    target.classList.add("explain-highlight")
    setTimeout(() => target.classList.remove("explain-highlight"), 2200)
  }

  // --- shared -------------------------------------------------------------

  show(el) {
    this.backdropTarget.hidden = false
    el.hidden = false
    requestAnimationFrame(() => el.classList.add("is-open"))
    const first = el.querySelector(".explain-close")
    ;(first || el).focus({ preventScroll: true })
  }

  closeAll({ restoreFocus }) {
    if (this.isClosed()) return
    ;[this.popoverTarget, this.panelTarget].forEach((el) => {
      el.hidden = true
      el.classList.remove("is-open")
    })
    this.backdropTarget.hidden = true
    if (this.opener) {
      this.opener.setAttribute("aria-expanded", "false")
      if (restoreFocus) this.opener.focus({ preventScroll: true })
    }
    this.opener = null
  }

  trapFocus(event) {
    const open = this.popoverTarget.hidden ? this.panelTarget : this.popoverTarget
    const items = [...open.querySelectorAll(FOCUSABLE)].filter((el) => !el.hidden)
    if (items.length === 0) return event.preventDefault()
    const first = items[0]
    const last = items[items.length - 1]
    if (event.shiftKey && (document.activeElement === first || document.activeElement === open)) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  markSeen(keys) {
    const seen = new Set(storage().read())
    keys.forEach((k) => seen.add(k))
    storage().write([...seen])
    this.refreshPageHelp()
  }
}
