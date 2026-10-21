module ExplainKit
  class Configuration
    # i18n namespace holding the glossary: explain.<key>.{title,short,long,how,more_url}
    attr_accessor :namespace

    # Locales the schema check (rake explain_kit:check) demands a complete glossary for.
    attr_accessor :required_locales

    # Callable (locale) -> { score: [{key:, min:, label:}, ...] }. The gem knows
    # nothing about the domain; the host injects its bands here.
    attr_accessor :bands

    # URL the browser fetches a term from when it is not embedded in the page
    # (terms inside lazy Turbo frames). Default matches the API contract.
    attr_accessor :glossary_path

    # Directories the check scans for explain_term(:key) / explain_term "key".
    attr_accessor :view_paths

    def initialize
      @namespace = :explain
      @required_locales = %i[en]
      @bands = ->(_locale) { {} }
      @glossary_path = "/api/v1/glossary"
      @view_paths = %w[app packs]
    end
  end
end
