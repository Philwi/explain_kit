module ExplainKit
  # Include in a host controller (so it inherits the host's throttling and
  # cache headers) and route `get "glossary"` to #show.
  module GlossaryEndpoint
    def show
      locale = I18n.available_locales.find { |l| l.to_s == params[:locale].to_s } || I18n.default_locale
      payload = GlossaryPayload.call(locale: locale)
      render json: payload if stale?(etag: payload["version"], public: true)
    end
  end
end
