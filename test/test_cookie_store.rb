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
    end

    assert_equal true, dummy_class.default_options[:persist_cookies]
  end
end
