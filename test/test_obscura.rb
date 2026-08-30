# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/http_mimic'

class ObscuraTest < Minitest::Test
  def setup
    HttpMimic.reset_configuration!
  end

  def test_obscura_configuration_defaults
    config = HttpMimic.configuration
    assert_equal 'v0.2.2', config.obscura_version
    assert_equal 'anxgang/obscura', config.obscura_github_repo
    assert_nil config.obscura_path
  end

  def test_obscura_platform_asset
    asset = HttpMimic::Downloader.obscura_platform_asset
    assert_match(/obscura-.*(macos|linux|windows)/, asset)
  end

  def test_obscura_binary_resolution_with_custom_path
    dummy_path = File.expand_path(__FILE__)
    HttpMimic.configure do |c|
      c.obscura_path = dummy_path
    end

    assert_equal dummy_path, HttpMimic::Obscura.resolve_binary
  end

  def with_stub(object, method_name, return_val)
    singleton = object.singleton_class
    original_method = object.respond_to?(method_name) ? object.method(method_name) : nil
    old_verbose = $VERBOSE
    $VERBOSE = nil
    singleton.send(:define_method, method_name) do |*args, &blk|
      return_val.is_a?(Proc) ? return_val.call(*args, &blk) : return_val
    end
    $VERBOSE = old_verbose
    yield
  ensure
    old_verbose = $VERBOSE
    $VERBOSE = nil
    if original_method
      singleton.send(:define_method, method_name, original_method)
    else
      singleton.send(:remove_method, method_name)
    end
    $VERBOSE = old_verbose
  end

  def test_render_alias_and_delegation
    dummy_html = '<html><head><title>Dynamic SPA Title</title></head><body><div id="root"><h3>Rendered Content</h3></div></body></html>'
    mock_status = Struct.new(:success?, :exitstatus).new(true, 0)

    with_stub(Open3, :capture3, [dummy_html, '', mock_status]) do
      with_stub(HttpMimic::Obscura, :resolve_binary, '/mock/bin/obscura') do
        resp = HttpMimic.render('https://example.com/spa')

        assert_equal 200, resp.code
        assert_equal 'Dynamic SPA Title', resp.title
        assert_includes resp.body, 'Rendered Content'
        assert_equal 'obscura', resp.headers['x-rendered-by']
      end
    end
  end

  def test_get_with_render_spa_option
    dummy_html = '<html><head><title>SPA via GET</title></head><body><h1>Hello SPA</h1></body></html>'
    mock_status = Struct.new(:success?, :exitstatus).new(true, 0)

    with_stub(Open3, :capture3, [dummy_html, '', mock_status]) do
      with_stub(HttpMimic::Obscura, :resolve_binary, '/mock/bin/obscura') do
        resp = HttpMimic.get('https://example.com/spa', render: :spa)

        assert_equal 200, resp.code
        assert_equal 'SPA via GET', resp.title
        assert_includes resp.body, 'Hello SPA'
      end
    end
  end

  def test_auto_render_spa_disabled_by_default
    raw_curl_out = "HTTP/2 200 OK\r\ncontent-type: text/html\r\n\r\n<html><body><div id=\"root\"></div><script src=\"/app.js\"></script></body></html>"
    mock_status = Struct.new(:success?, :exitstatus).new(true, 0)

    with_stub(Open3, :capture3, [raw_curl_out, '', mock_status]) do
      resp = HttpMimic.get('https://example.com/spa')

      # Without auto_render_spa, raw shell is returned directly
      assert_equal 200, resp.code
      assert_includes resp.body, '<div id="root"></div>'
      assert_nil resp.headers['x-rendered-by']
    end
  end

  def test_auto_render_spa_enabled_transitions_to_obscura
    raw_curl_out = "HTTP/2 200 OK\r\ncontent-type: text/html\r\n\r\n<html><body><div id=\"root\"></div><script src=\"/app.js\"></script></body></html>"
    rendered_html = '<html><head><title>Hydrated App</title></head><body><div id="root"><h1>Hydrated!</h1></div></body></html>'
    mock_status = Struct.new(:success?, :exitstatus).new(true, 0)

    # First call (curl) returns raw_curl_out, second call (obscura) returns rendered_html
    capture_proc = proc do |*args|
      if args.first.to_s.include?('obscura')
        [rendered_html, '', mock_status]
      else
        [raw_curl_out, '', mock_status]
      end
    end

    with_stub(Open3, :capture3, capture_proc) do
      with_stub(HttpMimic::Obscura, :resolve_binary, '/mock/bin/obscura') do
        resp = HttpMimic.get('https://example.com/spa', auto_render_spa: true)

        assert_equal 200, resp.code
        assert_equal 'Hydrated App', resp.title
        assert_includes resp.body, 'Hydrated!'
        assert_equal 'obscura', resp.headers['x-rendered-by']
      end
    end
  end
end
