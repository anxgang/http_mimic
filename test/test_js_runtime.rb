# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/http_mimic'

class JSRuntimeTest < Minitest::Test
  def setup
    HttpMimic.reset_configuration!
  end

  def test_qjs_platform_asset
    asset = HttpMimic::Downloader.qjs_platform_asset
    refute_nil asset
    assert_match(/(darwin|linux|windows)/, asset)
  end

  def test_qjs_download_and_eval
    # Test downloading and evaluating JS via HttpMimic
    qjs_bin = HttpMimic.download_qjs!
    assert File.exist?(qjs_bin), "Expected qjs binary to exist at #{qjs_bin}"
    assert HttpMimic.qjs_installed?

    result = HttpMimic.eval_js("1 + 2 * 3")
    assert_equal "7", result
  end

  def test_eval_js_json
    js_code = <<~JS
      const user = { id: 101, name: "Alice", active: true };
      user;
    JS

    parsed = HttpMimic.eval_js_json(js_code)
    assert_equal({ "id" => 101, "name" => "Alice", "active" => true }, parsed)
  end

  def test_browser_environment_mocking
    browser_mock = <<~JS
      const navigator = {
        userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/131.0.0.0 Safari/537.36",
        hardwareConcurrency: 8
      };
      const screen = { width: 1920, height: 1080 };
      
      ({
        ua: navigator.userAgent,
        cores: navigator.hardwareConcurrency,
        res: `${screen.width}x${screen.height}`
      });
    JS

    data = HttpMimic.eval_js_json(browser_mock)
    assert_equal "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/131.0.0.0 Safari/537.36", data["ua"]
    assert_equal 8, data["cores"]
    assert_equal "1920x1080", data["res"]
  end

  def test_js_error_handling
    err = assert_raises(HttpMimic::JSError) do
      HttpMimic.eval_js("throw new Error('Custom JS Failure!')")
    end

    assert_match(/Custom JS Failure!/, err.message)
    refute_nil err.stderr
  end
end
