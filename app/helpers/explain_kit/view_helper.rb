module ExplainKit
  module ViewHelper
    POPOVER_ID = "explain-popover".freeze
    PANEL_ID = "explain-page-help".freeze

    # Wraps inner content in an accessible trigger for glossary term `key`.
    #
    #   explain_term(:score) { "82" }                 # the content itself is the button (dotted underline)
    #   explain_term(:score, icon: true) { "82" }     # content stays plain, a small "?" button follows it
    #   explain_term(:score_band, bands: :score)      # popover lists the host's bands for :score
    #
    # Do not nest it inside a link or another button.
    def explain_term(key, icon: false, bands: nil, class: nil, **html, &block)
      key = key.to_s
      explain_keys << key
      inner = block ? capture(&block) : I18n.t("#{ExplainKit.config.namespace}.#{key}.title", default: key.humanize)
      title = I18n.t("#{ExplainKit.config.namespace}.#{key}.title", default: key.humanize)
      extra = binding.local_variable_get(:class)
      trigger = {
        type: "button",
        data: {explain_key: key, explain_bands: bands}.compact.merge(html.delete(:data) || {}),
        aria: {expanded: "false", controls: POPOVER_ID, haspopup: "dialog"}
      }

      if icon
        tag.span(class: ["explain-term", "explain-term--icon", extra]) do
          safe_join([
            inner,
            tag.button(**trigger, class: "explain-term__trigger", "aria-label": I18n.t("explain_kit.ui.explain", title: title)) do
              tag.span("?", "aria-hidden": "true")
            end
          ])
        end
      else
        tag.button(**trigger, class: ["explain-term", "explain-term--wrap", extra]) do
          safe_join([inner, tag.span(I18n.t("explain_kit.ui.explain_hint", title: title), class: "explain-sr")])
        end
      end
    end

    # The nav "?" button. Hidden until the page carries at least one explain_term.
    def explain_page_help(class: nil, label: nil, &block)
      @_explain_mount_wanted = true
      extra = binding.local_variable_get(:class)
      label ||= I18n.t("explain_kit.ui.page_help")
      tag.button(type: "button", hidden: true, class: ["explain-page-help", extra],
        data: {explain_page_help: true}, aria: {label: label, expanded: "false", controls: PANEL_ID, haspopup: "dialog"}) do
        safe_join([
          block ? capture(&block) : tag.span("?", "aria-hidden": "true"),
          tag.span("", class: "explain-dot", hidden: true, data: {explain_dot: true}, "aria-hidden": "true")
        ])
      end
    end

    # Embed terms that JavaScript renders (so the popover needs no request for them).
    def explain_preload(*keys)
      explain_keys.merge(keys.flatten.map(&:to_s))
      nil
    end

    # Once per page, at the end of <body>: the shared popover/sheet and the page-help panel.
    # Renders nothing when the page used no explain_term and has no page-help button.
    def explain_mount
      return if explain_keys.empty? && !@_explain_mount_wanted

      locale = I18n.locale
      terms = Glossary.terms(locale).slice(*explain_keys.to_a)
      payload = {terms: terms, bands: GlossaryPayload.call(locale: locale)["bands"]}
      render "explain_kit/mount", payload: payload, locale: locale
    end

    private

    def explain_keys = (@_explain_keys ||= Set.new)
  end
end
