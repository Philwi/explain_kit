require "bundler/setup"
require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "minitest/autorun"
require "explain_kit"

I18n.available_locales = %i[de en]
I18n.default_locale = :en
I18n.backend.store_translations(:en, explain: {
  spot: {
    score: {title: "Score", short: "How good the hour is.", long: "Long text.", more_url: "https://example.test/more", empty: ""},
    tide: {title: "Tide", short: "Band and times."}
  },
  common: {band: {title: "Band", short: "Ladder."}}
})
I18n.backend.store_translations(:de, explain: {spot: {score: {title: "Score", short: "Wie gut die Stunde ist."}}})
%w[en de].each { |l| I18n.backend.store_translations(l.to_sym, YAML.load_file(File.expand_path("../config/locales/explain_kit.#{l}.yml", __dir__))[l]) }

ExplainKit.configure do |c|
  c.required_locales = %i[en de]
  c.bands = ->(_locale) { {score: [{key: "epic", min: 80, label: "Epic"}, {key: "flat", min: 0, label: "Flat"}]} }
end

ViewPath = File.expand_path("../app/views", __dir__)
