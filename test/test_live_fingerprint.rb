# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/http_mimic'

class TestLiveFingerprint < Minitest::Test
  def setup
    HttpMimic.reset_configuration!
    HttpMimic.download_driver! unless HttpMimic.driver_installed?
  end

  def test_tls_browserleaks_chrome_fingerprint
    response = fetch_with_retry('https://tls.browserleaks.com/json', impersonate: 'chrome131', timeout: 20)
    skip 'tls.browserleaks.com is temporarily unreachable' if response.code.zero?

    assert_equal 200, response.code
    assert response.success?
    assert response.headers['content-type'].include?('json')

    data = response.parsed_response
    refute_nil data['ja3_hash'], 'Expected ja3_hash to be present'
    assert_equal 32, data['ja3_hash'].length, 'JA3 hash should be a 32-char MD5 hex string'
    assert_includes data['user_agent'], 'Chrome', 'User-Agent should simulate Chrome'
  end

  def test_tls_peet_ws_ja4_and_akamai_fingerprint
    response = fetch_with_retry('https://tls.peet.ws/api/all', impersonate: 'chrome131', timeout: 20)
    skip 'tls.peet.ws is temporarily unreachable' if response.code.zero?

    assert_equal 200, response.code
    assert response.success?

    data = response.parsed_response
    tls_info = data['tls'] || {}
    http2_info = data['http2'] || {}

    # JA4 fingerprint validation
    refute_nil tls_info['ja4'], 'Expected JA4 fingerprint to be present'
    assert_match(/^t\d{2}[a-z0-9]+/, tls_info['ja4'], 'JA4 format should start with TLS version flag')

    # Akamai HTTP/2 fingerprint validation
    akamai_fp = http2_info['akamai_fingerprint']
    refute_nil akamai_fp, 'Expected Akamai HTTP/2 fingerprint to be present'
    assert_includes akamai_fp, '|', 'Akamai fingerprint should contain pipe delimiters'
  end

  def test_different_browsers_produce_distinct_fingerprints
    chrome_res = fetch_with_retry('https://tls.browserleaks.com/json', impersonate: 'chrome131', timeout: 20)
    skip 'tls.browserleaks.com is temporarily unreachable' if chrome_res.code.zero?

    firefox_res = fetch_with_retry('https://tls.browserleaks.com/json', impersonate: 'firefox135', timeout: 20)
    skip 'tls.browserleaks.com is temporarily unreachable' if firefox_res.code.zero?

    assert_equal 200, chrome_res.code
    assert_equal 200, firefox_res.code

    chrome_ja3 = chrome_res.parsed_response['ja3_hash']
    firefox_ja3 = firefox_res.parsed_response['ja3_hash']

    refute_nil chrome_ja3
    refute_nil firefox_ja3
    refute_equal chrome_ja3, firefox_ja3, 'Chrome and Firefox must have different JA3 hashes'
  end

  def test_smart_auto_fallback_on_akamai_protected_site
    url = 'https://www.asics.com/us/en-us/gt-2000-15/p/ANA_1011C235-750.html'
    response = fetch_with_retry(url, timeout: 20)
    skip 'ASICS endpoint is temporarily unreachable' if response.code.zero?

    assert_equal 200, response.code
    assert response.success?
    assert_equal :curl, response.mode_used
    assert response.fallback_triggered?
  end

  def test_smart_auto_fallback_on_adidas_akamai_protected_site
    url = 'https://www.adidas.com.hk/en/KI8139.html'
    response = fetch_with_retry(url, timeout: 25)
    skip 'Adidas HK endpoint is temporarily unreachable' if response.code.zero?

    assert_equal 200, response.code
    assert response.success?
    assert_includes %i[android ios mobile curl], response.mode_used
    assert response.extract_images.size > 0
  end

  private

  def fetch_with_retry(url, options = {}, max_retries = 2)
    response = nil
    max_retries.times do
      response = HttpMimic.get(url, options)
      return response if response.code == 200
      sleep 1
    end
    response
  end
end
