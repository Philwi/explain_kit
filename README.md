# explain_kit

Rails engine for in-app explanations: a glossary that lives in the host's i18n files, a trigger helper
(`explain_term`), one shared popover (desktop) / bottom sheet (phone), a page help ("?") that lists every
term on the page, and `GET /api/v1/glossary` for native apps. The gem ships behaviour and structure. Texts
and styling stay in the host app.

Used by BreakFinder, later LiftSync and Stirra.

## Install

```ruby
# Gemfile
gem "explain_kit", git: "https://github.com/Philwi/explain_kit.git", branch: "main"
```

The repo is public, so `bundle install` needs no credentials, locally or in a Docker build.

```ruby
# config/initializers/explain_kit.rb
ExplainKit.configure do |c|
  c.required_locales = %i[de en]               # locales `explain_kit:check` demands complete
  c.glossary_path = "/api/v1/glossary"         # where the browser fetches terms not embedded in the page
  c.bands = ->(locale) { {score: [{key: "epic", min: 80, label: "Epic"}] } }  # host injects its bands
end
```

## Glossary schema

Namespaced by area in the host's locale files, addressed as `area.term`:

```yaml
en:
  explain:
    spot:
      breaker_height:
        title: "Breaker height"      # required
        short: "..."                 # required, one sentence
        long: "..."                  # optional
        how: "..."                   # optional, how it is worked out
        more_url: "https://..."      # optional
    common:
      score: ...
```

A node with a `title` is a term, anything else is an area. Empty fields are dropped from the API, never `null`.
`rake explain_kit:check` prints coverage per area and per view, then fails on a missing `title` or `short`
in any required locale, and on `explain_term` keys used in views but absent from the glossary.

## Views

```erb
<%= explain_term("spot.score") { "82" } %>                 <%# the content is the trigger, dotted underline %>
<%= explain_term("spot.score", icon: true) { "82" } %>     <%# content plain, small "?" button after it %>
<%= explain_term("common.score_band", bands: :score) %>    <%# popover also lists bands[:score] %>
<%= explain_term("common.units", page: false) { "m" } %>    <%# chrome (nav, switches): popover yes, page help list no %>

<%= explain_page_help class: "my-nav-button" %>             <%# nav "?": hidden until the page has terms, unseen dot %>
<%= explain_page_help data: {action: "click->sheet#close"} %> <%# a second entry point (e.g. a phone sheet): extra data attributes %>
<%= explain_mount %>                                        <%# once, at the end of <body> in every layout %>
```

Rules: do not nest a term inside a link or button (HTML forbids it). The wrapped content must be phrasing
content. `explain_mount` renders nothing when the page used no term, so it is safe in every layout.
The popover is positioned `absolute` against the page, keep `<body>` unpositioned.

## Styling hooks

Structural CSS only: `app/assets/stylesheets/explain_kit.css` (served by Propshaft/Sprockets, add
`stylesheet_link_tag "explain_kit"`). Theme with custom properties on `.explain-kit` (`--explain-bg`, `-fg`,
`-muted`, `-border`, `-accent`, `-radius`, `-shadow`, `-z`, `-width`, `-font`, `-underline`) or override the
classes: `.explain-term--wrap`, `.explain-term__trigger`, `.explain-pop`, `.explain-panel`, `.explain-close`,
`.explain-bands__item[data-band-key]` (set `--explain-band` per band), `.explain-list__item`,
`.explain-page-help`, `.explain-dot`, `.explain-highlight`. Scope per surface with a parent class.

## JavaScript

The controller is `app/javascript/explain_kit/controller.js` (Stimulus identifier `explain`). It is plain ESM
that imports `@hotwired/stimulus` from the host. Wire it without copying:

```js
// esbuild config: resolve "explain_kit/*" to the gem's JS directory
import { execSync } from "child_process"
const explainKit = execSync("bundle info explain_kit --path", { encoding: "utf8" }).trim() + "/app/javascript"
// esbuild options:
alias: { explain_kit: path.join(explainKit, "explain_kit") },
nodePaths: [path.join(process.cwd(), "node_modules")]   // the gem sits outside your tree: its `@hotwired/stimulus` import resolves here
```

Vitest needs the same `resolve.alias`. Hosts that render markup in JavaScript import
`explainTrigger(key, text, { bands, icon, label })` / `explainTriggerHTML(key, escapedHtml, options)` from
`explain_kit/trigger`. `icon: true` keeps the text plain and appends a "?" button; pass `label` ("What is Score?")
as its accessible name.

```js
// app/javascript/controllers/explain_controller.js
export { default } from "explain_kit/controller"
```

Then register it the way the host registers controllers (BreakFinder: `bin/generate_stimulus_lazy_loader`).
LiftSync (`web-app`) and Stirra (`breakfinder-ride-hub`) both use jsbundling-rails with esbuild or bun, so the
same alias works; for bun use `--alias` or a tsconfig `paths` entry pointing at the same directory.

Seen terms persist in `localStorage` (`explain_kit:seen`). Override with
`window.ExplainKitStorage = { read() { return [...] }, write(keys) { ... } }`.

Behaviour: Enter or tap opens, Escape closes and returns focus to the trigger, focus moves into the dialog
and is trapped while open, targets are at least 44px, `prefers-reduced-motion` turns animations off. Terms
inside lazy Turbo frames are not embedded in the page, the controller fetches them from `glossary_path`.
The desktop popover opens below its trigger, flips above it when there is more room there, and shrinks (and
scrolls) when neither side fits; it never covers the trigger. The page-help panel lists a term whose trigger is
not on screen (hidden tab, JS-revealed block) disabled, with a "not visible right now" hint, so there is no dead tap.

## Surfaces, tours and lazy content

- `data-explain-theme="x"` on a page wrapper: while a term inside it is open, `.explain-kit` carries
  `data-theme="x"`. The popover sits at the end of `<body>`, so this is how one app has several looks.
- `data-explain-tour="Label"` on any element: it is listed first in the page-help panel, and picking it
  clicks that element (a coach, an onboarding tour). A page with only a tour still gets the "?".
- `explain_preload("area.term", ...)`: embed terms that JavaScript or a lazy Turbo frame renders later.
  Everything else not embedded is fetched from `glossary_path` on first open.
- `explain_mount` also renders when `explain_page_help` was called, so the "?" works on every page.
- `ExplainKit::Glossary.coverage` / `.usage` back `rake explain_kit:check`, which prints terms per area and
  keys per view file before it validates.

## API

```ruby
# app/controllers/api/v1/glossary_controller.rb
class Api::V1::GlossaryController < Api::V1::PublicBaseController   # inherits host throttling and caching
  include ExplainKit::GlossaryEndpoint
end
# config/routes.rb:  get "glossary", to: "glossary#show"   (inside /api/v1)
```

`GET /api/v1/glossary?locale=de`:

```json
{"version": "a1b2c3d4", "locale": "de",
 "terms": {"spot.score": {"title": "...", "short": "...", "long": "...", "how": "...", "more_url": "..."}},
 "bands": {"score": [{"key": "epic", "min": 80, "label": "Epic"}]}}
```

`version` is a digest of the payload and doubles as ETag (`If-None-Match` answers `304`).
`ExplainKit::GlossaryPayload.call(locale:, bands:)` builds the same body for specs and fixtures.

## Rollout guide (adding a term)

1. Find the source of truth for the thing you explain (the service or ADR that decides it). The copy must
   describe what the code does, not what we wish it did. Cite the source in the PR.
2. Add `explain.<area>.<term>.{title,short}` (plus `long`, `how`, `more_url` when they help) in every
   required locale. `short` is one sentence a rider can read in two seconds. No dashes as punctuation,
   no corporate words, first person is fine.
3. Wrap the value or label in the view: `explain_term("area.term") { ... }`. Replace any `title=` tooltip
   or ad hoc help popover for the same thing.
4. Run `rake explain_kit:check`. It lists what each area and view already covers.
5. Native apps read the same keys from the API, so never rename a key after it shipped.

## Tests

```
bundle exec rake test
```
