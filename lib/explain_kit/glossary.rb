module ExplainKit
  # Reads the host's i18n namespace. Texts live in the host, never in the gem.
  #
  # Keys are namespaced by area: explain.<area>.<term>.{title,short,long,how,more_url}
  # and addressed as "area.term" (explain_term(:"spot.score")). A node that has a
  # String `title` is a term; anything else is an area and is walked.
  module Glossary
    FIELDS = %w[title short long how more_url].freeze
    REQUIRED = %w[title short].freeze
    USE = /explain_term[ (]\s*[:"']([a-z0-9_.]+)/

    module_function

    # @return [Hash{String => Hash{String => String}}] "area.term" => present fields only
    def terms(locale)
      raw = I18n.t(ExplainKit.config.namespace, locale: locale, default: {})
      flatten(raw).each_with_object({}) do |(key, fields), out|
        clean = fields.slice(*FIELDS).select { |_, v| v.is_a?(String) && !v.strip.empty? }
        out[key] = clean unless clean.empty?
      end
    end

    # Own translations of a locale, ignoring fallbacks (the check must see real gaps).
    def own_terms(locale)
      backend = I18n.backend
      backend.send(:init_translations) unless backend.initialized?
      flatten(backend.translations.dig(locale.to_sym, ExplainKit.config.namespace.to_sym) || {})
    end

    # @return [Hash{String => Array<String>}] area => term keys, from the first required locale
    def coverage(locale = ExplainKit.config.required_locales.first)
      own_terms(locale).keys.group_by { |k| k.split(".").first }
    end

    # @return [Hash{String => Array<String>}] view file => keys it uses
    def usage(roots = ExplainKit.config.view_paths)
      roots.flat_map { |r| Dir.glob(File.join(r, "**/*.{erb,haml,slim,rb}")) }.sort.each_with_object({}) do |file, out|
        keys = File.read(file).scan(USE).flatten.uniq
        out[file] = keys if keys.any?
      end
    end

    # @return [Array<String>] human readable problems, empty when the glossary is sound
    def problems(locales: ExplainKit.config.required_locales, used_keys: [])
      known = locales.flat_map { |l| own_terms(l).keys }.uniq
      errors = locales.flat_map do |locale|
        own = own_terms(locale)
        known.flat_map do |key|
          fields = own[key] || {}
          REQUIRED.filter_map do |f|
            "#{locale}: explain.#{key}.#{f} missing" if fields[f].to_s.strip.empty?
          end
        end
      end
      errors + (used_keys.map(&:to_s).uniq - known).map { |k| "explain_term(:#{k}) used in a view but not in the glossary" }
    end

    def used_keys(roots = ExplainKit.config.view_paths) = usage(roots).values.flatten.uniq

    def flatten(node, prefix = nil)
      return {} unless node.is_a?(Hash)

      node.each_with_object({}) do |(key, value), out|
        next unless value.is_a?(Hash)

        path = [prefix, key].compact.join(".")
        fields = value.transform_keys(&:to_s)
        if fields.key?("title") || fields.key?("short")
          out[path] = fields
        else
          out.merge!(flatten(value, path))
        end
      end
    end
  end
end
