module ExplainKit
  # The `GET /api/v1/glossary` body. Empty fields are absent, never null.
  module GlossaryPayload
    module_function

    def call(locale:, bands: nil)
      locale = locale.to_sym
      bands = (bands || ExplainKit.config.bands.call(locale)).transform_keys(&:to_s)
      body = {
        "locale" => locale.to_s,
        "terms" => Glossary.terms(locale),
        "bands" => bands.transform_values { |list| list.map { |b| b.transform_keys(&:to_s) } }
      }
      {"version" => Digest::SHA256.hexdigest(JSON.generate(body))[0, 8]}.merge(body)
    end
  end
end
