module ExplainKit
  # Include in a host controller (so it inherits the host's throttling and
  # cache headers) and route `get "glossary"` to #show.
  module GlossaryEndpoint
    # Maps a client locale string onto an available I18n locale. Clients send
    # BCP-47 tags (`pt-BR`), sometimes `pt_BR`, in any casing; I18n locales use
    # underscores (`:pt_BR`). Tries the full tag, then the language part, then
    # the default locale.
    def self.resolve_locale(raw)
      tag = raw.to_s.strip.tr("-", "_").downcase
      return I18n.default_locale if tag.empty?

      by_tag = I18n.available_locales.index_by { |l| l.to_s.downcase }
      by_tag[tag] || by_tag[tag.split("_").first] || I18n.default_locale
    end

    def show
      payload = GlossaryPayload.call(locale: GlossaryEndpoint.resolve_locale(params[:locale]))
      render json: payload if stale?(etag: payload["version"], public: true)
    end
  end
end
