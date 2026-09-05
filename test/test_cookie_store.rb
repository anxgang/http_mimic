# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/http_mimic'

class CookieStoreTest < Minitest::Test
  def setup
    HttpMimic.reset_configuration!
    @tmp_dir = File.expand_path('../tmp/test_cookies', __dir__)
    HttpMimic.configure do |c|
      c.cookie_store_dir = @tmp_dir
    end
    HttpMimic.clear_cookies!
  end

  def teardown
    HttpMimic.clear_cookies!
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_cookie_save_and_load
    host = 'www.adidas.com'
    cookies = { '_abck' => 'valid_token_123', 'bm_sz' => 'xyz' }

    HttpMimic.save_cookies(host, cookies)

    loaded = HttpMimic.load_cookies(host)
    assert_equal 'valid_token_123', loaded['_abck']
    assert_equal 'xyz', loaded['bm_sz']

    # Test file location
    file = HttpMimic::CookieStore.cookie_file_for(host)
    assert File.exist?(file)
  end

  def test_cookie_expiry
    host = 'www.example.com'
    cookies = { 'session' => '123' }

    HttpMimic.save_cookies(host, cookies)

    # Test immediate load
    assert_equal '123', HttpMimic.load_cookies(host, max_age: 10)['session']

    # Test expired load
    assert_equal({}, HttpMimic.load_cookies(host, max_age: -1))
  end

  def test_navigation_headers_injection_chrome
    builder = HttpMimic::CommandBuilder.new(
      :get,
      'https://www.adidas.com/om/en/item.html',
      { profile: :impersonate, impersonate: 'chrome131' }
    )

    _bin, args, = builder.build
    assert_includes args, 'sec-fetch-dest: document'
    assert_includes args, 'sec-fetch-mode: navigate'
    assert_includes args, 'sec-fetch-site: none'
    assert_includes args, 'upgrade-insecure-requests: 1'
    assert_includes args, 'sec-ch-ua: "Google Chrome";v="131", "Chromium";v="131", "Not_A Brand";v="24"'
    assert_includes args, 'sec-ch-ua-mobile: ?0'
    assert_includes args, 'sec-ch-ua-platform: "macOS"'
  end

  def test_navigation_headers_injection_firefox
    builder = HttpMimic::CommandBuilder.new(
      :get,
      'https://www.example.com',
      { impersonate: 'firefox135' }
    )

    _bin, args, = builder.build
    assert_includes args, 'sec-fetch-dest: document'
    assert_includes args, 'sec-fetch-mode: navigate'
    assert_includes args, 'sec-fetch-site: none'
    assert_includes args, 'upgrade-insecure-requests: 1'
    assert_includes args, 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8'
    assert_includes args, 'accept-language: en-US,en;q=0.5'

    # Firefox must NOT have sec-ch-ua headers!
    refute args.any? { |a| a.start_with?('sec-ch-ua') }
  end

  def test_navigation_headers_injection_safari
    builder = HttpMimic::CommandBuilder.new(
      :get,
      'https://www.example.com',
      { impersonate: 'safari180' }
    )

    _bin, args, = builder.build
    assert_includes args, 'sec-fetch-dest: document'
    assert_includes args, 'sec-fetch-mode: navigate'
    assert_includes args, 'sec-fetch-site: none'
    assert_includes args, 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    assert_includes args, 'accept-language: en-US,en;q=0.9'

    # Safari must NOT have sec-ch-ua headers!
    refute args.any? { |a| a.start_with?('sec-ch-ua') }
  end

  def test_navigation_headers_injection_edge
    builder = HttpMimic::CommandBuilder.new(
      :get,
      'https://www.example.com',
      { impersonate: 'edge101' }
    )

    _bin, args, = builder.build
    assert_includes args, 'sec-ch-ua: "Microsoft Edge";v="101", "Chromium";v="101", "Not_A Brand";v="24"'
    assert_includes args, 'sec-ch-ua-mobile: ?0'
    assert_includes args, 'sec-ch-ua-platform: "Windows"'
  end

  def test_navigation_headers_injection_android
    builder = HttpMimic::CommandBuilder.new(
      :get,
      'https://www.example.com',
      { profile: :android }
    )

    _bin, args, = builder.build
    assert_includes args, 'sec-ch-ua-mobile: ?1'
    assert_includes args, 'sec-ch-ua-platform: "Android"'
    assert_includes args, 'sec-ch-ua: "Chromium";v="131", "Not_A Brand";v="24", "Google Chrome";v="131"'
  end

  def test_persist_cookies_in_module_methods
    dummy_class = Class.new do
      include HttpMimic
      persist_cookies true
      persist_on_failure true
      clear_on_failure false
    end

    assert_equal true, dummy_class.default_options[:persist_cookies]
    assert_equal true, dummy_class.default_options[:persist_on_failure]
    assert_equal false, dummy_class.default_options[:clear_on_failure]
  end

  def test_configuration_defaults_for_failure_handling
    assert_equal false, HttpMimic.configuration.persist_on_failure
    assert_equal true, HttpMimic.configuration.clear_on_failure
  end

  def mock_request_execution(req, stdout, stderr = '', exitstatus = 0)
    status = Struct.new(:exitstatus).new(exitstatus)
    req.define_singleton_method(:execute_open3) do |*args|
      [stdout, stderr, status]
    end
  end

  def test_does_not_persist_cookies_on_403_by_default
    host = 'blocked.example.com'
    url = "https://#{host}/secret"

    raw_403 = "HTTP/2 403 Forbidden\r\nSet-Cookie: bot_detected=1; Path=/\r\n\r\nForbidden"
    req = HttpMimic::Request.new(:get, url, persist_cookies: true, auto_fallback: false)
    mock_request_execution(req, raw_403)
    req.perform

    # By default, persist_on_failure is false, so bot_detected cookie must NOT be saved
    loaded = HttpMimic.load_cookies(host)
    assert_nil loaded['bot_detected']
  end

  def test_persists_cookies_on_403_when_persist_on_failure_is_true
    host = 'save-failure.example.com'
    url = "https://#{host}/secret"

    raw_403 = "HTTP/2 403 Forbidden\r\nSet-Cookie: debug_cookie=xyz; Path=/\r\n\r\nForbidden"
    req = HttpMimic::Request.new(:get, url, persist_cookies: true, persist_on_failure: true, auto_fallback: false)
    mock_request_execution(req, raw_403)
    req.perform

    loaded = HttpMimic.load_cookies(host)
    assert_equal 'xyz', loaded['debug_cookie']
  end

  def test_clears_stored_cookies_on_verification_failure_by_default
    host = 'tainted.example.com'
    url = "https://#{host}/profile"

    # Pre-populate with an existing (now expired or tainted) cookie
    HttpMimic.save_cookies(host, { 'old_session' => 'expired_token' })
    assert_equal 'expired_token', HttpMimic.load_cookies(host)['old_session']

    raw_403 = "HTTP/2 403 Forbidden\r\nSet-Cookie: block_token=abc; Path=/\r\n\r\nForbidden"
    req = HttpMimic::Request.new(:get, url, persist_cookies: true, auto_fallback: false)
    mock_request_execution(req, raw_403)
    req.perform

    # With default clear_on_failure: true, the tainted cookies must be wiped
    loaded = HttpMimic.load_cookies(host)
    assert_empty loaded
  end

  def test_does_not_clear_stored_cookies_when_clear_on_failure_is_false
    host = 'keep-tainted.example.com'
    url = "https://#{host}/profile"

    HttpMimic.save_cookies(host, { 'old_session' => 'keep_this' })
    assert_equal 'keep_this', HttpMimic.load_cookies(host)['old_session']

    raw_403 = "HTTP/2 403 Forbidden\r\nSet-Cookie: block_token=abc; Path=/\r\n\r\nForbidden"
    req = HttpMimic::Request.new(:get, url, persist_cookies: true, clear_on_failure: false, auto_fallback: false)
    mock_request_execution(req, raw_403)
    req.perform

    # Preserves existing cookies because clear_on_failure is false
    loaded = HttpMimic.load_cookies(host)
    assert_equal 'keep_this', loaded['old_session']
    # And does NOT save the new failed cookie
    assert_nil loaded['block_token']
  end

  def test_clears_cookies_on_waf_challenge_page_even_with_200_status
    host = 'waf-challenge.example.com'
    url = "https://#{host}/protected"

    HttpMimic.save_cookies(host, { 'session' => 'old_val' })

    # 200 OK status but containing Cloudflare Turnstile challenge
    raw_challenge = "HTTP/2 200 OK\r\nSet-Cookie: cf_clearance=failed; Path=/\r\n\r\n<html><div class=\"cf-turnstile\"></div></html>"
    req = HttpMimic::Request.new(:get, url, persist_cookies: true, auto_fallback: false, solve_waf: false)
    mock_request_execution(req, raw_challenge)
    req.perform

    # Challenge page means verification failed: cleared, and cf_clearance not persisted
    loaded = HttpMimic.load_cookies(host)
    assert_empty loaded
  end

  def test_persists_cookies_on_200_success
    host = 'success.example.com'
    url = "https://#{host}/welcome"

    raw_200 = "HTTP/2 200 OK\r\nSet-Cookie: auth_token=good_session; Path=/\r\n\r\n<h1>Welcome</h1>"
    req = HttpMimic::Request.new(:get, url, persist_cookies: true, auto_fallback: false)
    mock_request_execution(req, raw_200)
    req.perform

    loaded = HttpMimic.load_cookies(host)
    assert_equal 'good_session', loaded['auth_token']
  end
end
