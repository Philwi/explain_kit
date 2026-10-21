require "rails/engine"

module ExplainKit
  class Engine < ::Rails::Engine
    isolate_namespace ExplainKit

    initializer "explain_kit.helpers" do
      ActiveSupport.on_load(:action_view) { include ExplainKit::ViewHelper }
    end

    # Propshaft / Sprockets pick up app/assets/stylesheets/explain_kit.css from the engine.
    rake_tasks { load File.expand_path("../tasks/explain_kit.rake", __dir__) }
  end
end
