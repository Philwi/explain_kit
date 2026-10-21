namespace :explain_kit do
  desc "Coverage per area and view, then fail on missing title/short per required locale and on unknown keys"
  task check: :environment do
    kit = ExplainKit::Glossary
    puts "Glossary (#{ExplainKit.config.required_locales.join(", ")}):"
    kit.coverage.sort.each { |area, keys| puts "  #{area.ljust(10)} #{keys.size}  #{keys.map { |k| k.split(".", 2).last }.join(", ")}" }
    usage = kit.usage
    puts "Views using explain_term (#{usage.size}):"
    usage.each { |file, keys| puts "  #{file}: #{keys.join(", ")}" }

    problems = kit.problems(used_keys: usage.values.flatten)
    abort(problems.join("\n")) if problems.any?
    puts "explain_kit: glossary ok"
  end

  desc "Print the gem's JS directory (alias it in the host's esbuild config)"
  task :js_path do
    puts File.expand_path("../../app/javascript", __dir__)
  end
end
