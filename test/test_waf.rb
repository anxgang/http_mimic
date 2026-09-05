# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/http_mimic'

class WafTest < Minitest::Test
  def setup
    HttpMimic.reset_configuration!
  end

  def test_akamai_detection
    html = <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>adidas</title></head>
      <body>
        Reference Error: 0.12345.6789 Akamai
        <script src="/zY8IXY-VX4jQB389EA/JN7wDVi9O7ON/d1ZyVyoB/GWwZOEJ/xKlQX?v=9f10a097"></script>
      </body>
      </html>
    HTML

    raw = "HTTP/2 403 Forbidden\r\nset-cookie: _abck=123~-1~-1\r\n\r\n#{html}"
    resp = HttpMimic::ResponseParser.new(raw).parse

    assert_equal :akamai, HttpMimic.detect_waf(resp)
    assert_equal :akamai, HttpMimic::Waf::Detector.detect(resp)
  end

  def test_cloudflare_detection
    raw = "HTTP/2 403 Forbidden\r\nserver: cloudflare\r\ncf-ray: 12345678\r\n\r\nJust a moment..."
    resp = HttpMimic::ResponseParser.new(raw).parse

    assert_equal :cloudflare, HttpMimic.detect_waf(resp)
  end

  def test_datadome_detection
    raw = "HTTP/2 403 Forbidden\r\nx-datadome: protected\r\n\r\nAccess denied"
    resp = HttpMimic::ResponseParser.new(raw).parse

    assert_equal :datadome, HttpMimic.detect_waf(resp)
  end

  def test_akamai_sensor_url_extraction
    html = '<script type="text/javascript" src="/akam/13/2f2a7a4?v=1234"></script>'
    url = HttpMimic::Waf::AkamaiSolver.extract_sensor_script_url('https://example.com/item/1', html)
    assert_equal 'https://example.com/akam/13/2f2a7a4?v=1234', url
  end

  def test_dynamic_browser_context_execution
    context_js = File.read(File.expand_path('../lib/http_mimic/waf/browser_context.js', __dir__))
    target_url = 'https://shop.nike.com/us/en/shoes/pegasus?size=10#details'
    doc_title = 'Nike Air Pegasus - Running Shoes'
    custom_ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'

    script = <<~JS
      globalThis.__TARGET_URL__ = #{target_url.to_json};
      globalThis.__DOCUMENT_TITLE__ = #{doc_title.to_json};
      globalThis.__USER_AGENT__ = #{custom_ua.to_json};
      globalThis.__INITIAL_COOKIES__ = "session_id=abc999; token=xyz";

      #{context_js}

      ({
        href: location.href,
        origin: location.origin,
        host: location.host,
        hostname: location.hostname,
        pathname: location.pathname,
        search: location.search,
        hash: location.hash,
        title: document.title,
        cookie: document.cookie,
        ua: navigator.userAgent,
        platform: navigator.platform
      });
    JS

    result = HttpMimic.eval_js_json(script)
    assert_equal target_url, result['href']
    assert_equal 'https://shop.nike.com', result['origin']
    assert_equal 'shop.nike.com', result['host']
    assert_equal 'shop.nike.com', result['hostname']
    assert_equal '/us/en/shoes/pegasus', result['pathname']
    assert_equal '?size=10', result['search']
    assert_equal '#details', result['hash']
    assert_equal doc_title, result['title']
    assert_equal 'session_id=abc999; token=xyz', result['cookie']
    assert_equal custom_ua, result['ua']
    assert_equal 'Win32', result['platform']
  end

  def test_google_detection
    raw = "HTTP/2 200 OK\r\nserver: gws\r\n\r\n<!DOCTYPE html><html><body><noscript><meta http-equiv=\"refresh\" content=\"0;url=/httpservice/retry/enablejs?sei=123\"></noscript></body></html>"
    resp = HttpMimic::ResponseParser.new(raw).parse

    assert_equal :google, HttpMimic.detect_waf(resp)
    assert_equal :google, HttpMimic::Waf::Detector.detect(resp)
    assert HttpMimic::Waf::Detector.challenge_page?(resp)
  end

  def test_akamai_verified_abck_detection
    cookies_unverified = { '_abck' => 'UUID~-1~encrypted~xyz' }
    cookies_verified = { '_abck' => 'UUID~0~encrypted~xyz' }

    refute HttpMimic::Waf::AkamaiSolver.verified_abck?(cookies_unverified)
    assert HttpMimic::Waf::AkamaiSolver.verified_abck?(cookies_verified)
    refute HttpMimic::Waf::AkamaiSolver.verified_abck?({})
    refute HttpMimic::Waf::AkamaiSolver.verified_abck?(nil)
  end

  def test_akamai_build_driver_script_two_phase
    script_p1 = HttpMimic::Waf::AkamaiSolver.build_driver_script(
      target_url: 'https://example.com/items',
      doc_title: 'Title',
      cookie_str: 'session=1',
      referer: 'https://example.com/',
      phase: 1
    )
    assert_includes script_p1, 'globalThis.__TELEMETRY_PHASE__ = 1;'

    script_p2 = HttpMimic::Waf::AkamaiSolver.build_driver_script(
      target_url: 'https://example.com/items',
      doc_title: 'Title',
      cookie_str: 'session=1; bm_s=xyz',
      referer: 'https://example.com/',
      phase: 2
    )
    assert_includes script_p2, 'globalThis.__TELEMETRY_PHASE__ = 2;'
  end

  def test_akamai_extract_sensor_script_url_with_html_entities_and_params
    html = '<body><script type="text/javascript" src="/GPv76JOU160CMneR0n-v19eGZa4/f0N14VQa9b/UXwvAQ/TiJIQ1N/mGAQa?v=67eebcce-63c0-8786-c1d9-b10f59dacb42&amp;t=134988548"></script></body>'
    url = HttpMimic::Waf::AkamaiSolver.extract_sensor_script_url('https://example.com/item.html', html)
    assert_equal 'https://example.com/GPv76JOU160CMneR0n-v19eGZa4/f0N14VQa9b/UXwvAQ/TiJIQ1N/mGAQa?v=67eebcce-63c0-8786-c1d9-b10f59dacb42&t=134988548', url
  end

  def test_akamai_post_sensor_data_resolves_relative_and_empty_url
    target_url = 'https://example.com/page.html'
    sensor_url = 'https://example.com/sensor.js'
    impersonate = 'chrome131'
    cookies = HttpMimic::Cookies.new
    posts = [
      { 'url' => '', 'headers' => { 'Content-Type' => 'application/json' }, 'body' => '{"body":"xyz"}' },
      { 'url' => '/api/telemetry', 'headers' => { 'Content-Type' => 'application/json' }, 'body' => '{"body":"abc"}' }
    ]

    posted_calls = []
    old_post = HttpMimic.method(:post)
    singleton = HttpMimic.singleton_class
    old_verbose = $VERBOSE
    $VERBOSE = nil
    singleton.send(:define_method, :post) do |url, opts|
      posted_calls << { url: url, opts: opts }
      Struct.new(:cookies).new({ '_abck' => 'updated' })
    end
    $VERBOSE = old_verbose

    begin
      HttpMimic::Waf::AkamaiSolver.post_sensor_data(sensor_url, target_url, impersonate, cookies, posts)
    ensure
      $VERBOSE = nil
      singleton.send(:define_method, :post, old_post)
      $VERBOSE = old_verbose
    end

    assert_equal 2, posted_calls.size
    assert_equal 'https://example.com/page.html', posted_calls[0][:url]
    assert_equal 'application/json', posted_calls[0][:opts][:headers]['Content-Type']
    assert_equal 'https://example.com/api/telemetry', posted_calls[1][:url]
    assert_equal 'updated', cookies['_abck']
  end
end
