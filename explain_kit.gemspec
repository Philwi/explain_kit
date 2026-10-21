require_relative "lib/explain_kit/version"

Gem::Specification.new do |s|
  s.name = "explain_kit"
  s.version = ExplainKit::VERSION
  s.authors = ["Philipp Winkler"]
  s.summary = "Glossary, explain popovers, page help and a glossary API for Rails apps"
  s.homepage = "https://github.com/Philwi/explain_kit"
  s.license = "Nonstandard"
  s.required_ruby_version = ">= 3.2"
  s.files = Dir["{app,config,lib}/**/*", "README.md"]
  s.add_dependency "rails", ">= 7.1"
end
