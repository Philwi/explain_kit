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

  def test_chrome_term_opts_out_of_the_page_help
    assert_includes view.explain_term("spot.score", page: false) { "82" }, 'data-explain-page="false"'
    refute_includes view.explain_term("spot.score") { "82" }, "data-explain-page"
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

  def test_mount_carries_the_hint_for_terms_that_are_not_visible
    view.explain_term("spot.score") { "1" }
    assert_includes view.explain_mount, 'data-hidden-hint="Not visible on this page right now"'
  end

  def test_mount_is_empty_without_terms
    assert_nil view.explain_mount
  end

  def test_mount_renders_for_the_page_help_button_alone
    view.explain_page_help
    assert_includes view.explain_mount, 'data-controller="explain"'
  end

  def test_preload_embeds_terms_without_markup
    view.explain_preload("spot.tide")
    assert_includes view.explain_mount, "spot.tide"
  end

  def test_page_help_button_takes_extra_data_for_a_second_entry_point
    html = view.explain_page_help(data: {action: "click->sheet#close"})
    assert_includes html, 'data-action="click-&gt;sheet#close"'
    assert_includes html, "data-explain-page-help"
  end

  def test_page_help_button_starts_hidden_with_dot
    html = view.explain_page_help
    assert_includes html, "hidden"
    assert_includes html, "data-explain-page-help"
    assert_includes html, "data-explain-dot"
  end
end

class LocaleResolutionTest < Minitest::Test
  def setup
    @saved = I18n.available_locales
    I18n.available_locales = %i[de en pt pt_BR]
  end

  def teardown
    I18n.available_locales = @saved
  end

  def resolve(raw) = ExplainKit::GlossaryEndpoint.resolve_locale(raw)

  def test_bcp47_tag_matches_underscore_locale
    assert_equal :pt_BR, resolve("pt-BR")
  end

  def test_underscore_and_any_casing_match
    assert_equal :pt_BR, resolve("pt_BR")
    assert_equal :pt_BR, resolve("pt_br")
    assert_equal :pt_BR, resolve("PT-br")
  end

  def test_exact_plain_locale_matches
    assert_equal :de, resolve("de")
  end

  def test_unavailable_region_falls_back_to_language_part
    assert_equal :de, resolve("de-AT")
    assert_equal :pt, resolve("pt-PT")
  end

  def test_unknown_blank_or_nil_fall_back_to_default
    assert_equal :en, resolve("xx-YY")
    assert_equal :en, resolve("")
    assert_equal :en, resolve(nil)
  end
end
