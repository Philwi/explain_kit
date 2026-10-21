require "test_helper"
require "action_view"
require_relative "../app/helpers/explain_kit/view_helper"

class GlossaryTest < Minitest::Test
  def test_flattens_areas_and_drops_empty_fields
    terms = ExplainKit::Glossary.terms(:en)
    assert_equal %w[common.band spot.score spot.tide], terms.keys.sort
    assert_equal %w[long more_url short title], terms["spot.score"].keys.sort
  end

  def test_schema_check_flags_missing_locale_entry_and_unknown_view_key
    problems = ExplainKit::Glossary.problems(used_keys: %w[spot.score spot.nope])
    assert_includes problems, "de: explain.spot.tide.title missing"
    assert_includes problems, "de: explain.common.band.short missing"
    assert_includes problems, "explain_term(:spot.nope) used in a view but not in the glossary"
    refute(problems.any? { |p| p.include?("spot.score") && p.start_with?("de:") })
  end

  def test_coverage_groups_by_area
    assert_equal({"common" => ["common.band"], "spot" => ["spot.score", "spot.tide"]}, ExplainKit::Glossary.coverage(:en))
  end
end

class PayloadTest < Minitest::Test
  def test_shape_version_and_no_nulls
    payload = ExplainKit::GlossaryPayload.call(locale: :en)
    assert_equal "en", payload["locale"]
    assert_match(/\A\h{8}\z/, payload["version"])
    assert_equal "epic", payload["bands"]["score"].first["key"]
    refute_includes JSON.generate(payload), "null"
  end

  def test_version_changes_with_content
    a = ExplainKit::GlossaryPayload.call(locale: :en)["version"]
    b = ExplainKit::GlossaryPayload.call(locale: :de)["version"]
    refute_equal a, b
    assert_equal a, ExplainKit::GlossaryPayload.call(locale: :en)["version"]
  end

  def test_explicit_bands_win
    payload = ExplainKit::GlossaryPayload.call(locale: :en, bands: {score: [{key: "x", min: 1, label: "X"}]})
    assert_equal ["x"], payload["bands"]["score"].map { |b| b["key"] }
  end
end

class HelperTest < Minitest::Test
  def view
    @view ||= ActionView::Base.with_empty_template_cache.with_view_paths([ViewPath]).tap { |v| v.extend(ExplainKit::ViewHelper) }
  end

  def test_wrap_trigger_has_accessibility_attributes
    html = view.explain_term("spot.score") { "82" }
    assert_includes html, '<button'
    assert_includes html, 'type="button"'
    assert_includes html, 'data-explain-key="spot.score"'
    assert_includes html, 'aria-expanded="false"'
    assert_includes html, 'aria-controls="explain-popover"'
    assert_includes html, 'aria-haspopup="dialog"'
    assert_includes html, "82"
  end

  def test_icon_trigger_names_the_term
    html = view.explain_term("spot.score", icon: true) { "82" }
    assert_includes html, 'aria-label="What is Score?"'
    assert_includes html, "explain-term__trigger"
  end

  def test_mount_embeds_only_used_terms_and_bands
    view.explain_term("spot.score") { "1" }
    html = view.explain_mount
    assert_includes html, 'role="dialog"'
    assert_includes html, "spot.score"
    refute_includes html, "spot.tide"
    assert_includes html, '"epic"'
  end

  def test_mount_is_empty_without_terms
    assert_nil view.explain_mount
  end

  def test_page_help_button_starts_hidden_with_dot
    html = view.explain_page_help
    assert_includes html, "hidden"
    assert_includes html, "data-explain-page-help"
    assert_includes html, "data-explain-dot"
  end
end
