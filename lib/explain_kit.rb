require "digest"
require "json"
require "explain_kit/version"
require "explain_kit/configuration"
require "explain_kit/glossary"
require "explain_kit/glossary_payload"
require "explain_kit/glossary_endpoint"
require "explain_kit/engine"

module ExplainKit
  class << self
    def config = (@config ||= Configuration.new)

    def configure = yield(config)

    # For tests.
    def reset! = (@config = nil)
  end
end
