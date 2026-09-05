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

  def test_akamai_extract_multi_sensor_script_urls
    html = <<~HTML
      <html><body>
        <script type="text/javascript" src="/GPv76JOU160CMneR0n-v19eGZa4/f0N14VQa9b/UXwvAQ/Cwo-Rxc/cPwAa?v=3266b183&amp;t=13894798"></script>
        <script type="text/javascript" src="/GPv76JOU160CMneR0n-v19eGZa4/tEN14VQa9bzOc7f7/WGYpAQ/RAR7bB9/GBxMB"></script>
      </body></html>
    HTML
    urls = HttpMimic::Waf::AkamaiSolver.extract_sensor_script_urls('https://www.adidas.com/page.html', html)
    assert_equal 2, urls.size
    assert_includes urls[0], 't=13894798'
    assert_includes urls[1], 'RAR7bB9/GBxMB'
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

  def test_akamai_verified_bm_sc_detection
    cookies_bm_sc_verified = { 'bm_sc' => '1~1~997096923~token~0~0~0' }
    cookies_bm_sc_unverified = { 'bm_sc' => '3~1~997096923~token~0~0~0' }

    assert HttpMimic::Waf::AkamaiSolver.verified_abck?(cookies_bm_sc_verified)
    refute HttpMimic::Waf::AkamaiSolver.verified_abck?(cookies_bm_sc_unverified)
  end

  def test_browser_context_dom_and_history_support
    context_js = File.read(HttpMimic::Waf::AkamaiSolver::CONTEXT_JS_PATH)
    test_script = <<~JS
      globalThis.__TARGET_URL__ = "https://www.example.com/products/shoes.html";
      #{context_js}

      var a = document.createElement("a");
      a.href = "https://www.example.com/checkout";

      var s = document.createElement("script");
      s.src = "/tracker.js?t=123";
      document.body.appendChild(s);

      history.pushState({ step: 1 }, "Checkout", "/checkout");

      JSON.stringify({
        doc_location_matches: document.location === location,
        window_doc_matches: window.document === document,
        history_state: history.state,
        a_protocol: a.protocol,
        a_hostname: a.hostname,
        script_src: document.getElementsByTagName("script")[0].src
      });
    JS

    result = HttpMimic::JSRuntime.eval_json(test_script)
    assert result['doc_location_matches']
    assert result['window_doc_matches']
    assert_equal({ 'step' => 1 }, result['history_state'])
    assert_equal 'https:', result['a_protocol']
    assert_equal 'www.example.com', result['a_hostname']
    assert_equal '/tracker.js?t=123', result['script_src']
  end

  def test_browser_context_shader_and_v8_jit_characteristics
    context_js = File.read(HttpMimic::Waf::AkamaiSolver::CONTEXT_JS_PATH)
    test_script = <<~JS
      globalThis.__TARGET_URL__ = "https://www.example.com/item.html";
      #{context_js}

      // 1. Native reflection test
      var toStringCallResult = Function.prototype.toString.call(document.createElement);
      var nativeToStringName = Function.prototype.toString.name;

      // 2. WebGL shader parameters and extensions
      var canvas = document.createElement("canvas");
      var gl = canvas.getContext("webgl");
      var ext = gl.getExtension("WEBGL_debug_renderer_info");
      var vendor = gl.getParameter(ext.UNMASKED_VENDOR_WEBGL);
      var renderer = gl.getParameter(ext.UNMASKED_RENDERER_WEBGL);
      var exts = gl.getSupportedExtensions();

      // ReadPixels pipeline
      gl.clearColor(0.8, 0.4, 0.2, 1.0);
      var px = new Uint8Array(4);
      gl.readPixels(0, 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, px);

      // 3. Virtual JIT Clock monotonic & quantization test
      var t1 = performance.now();
      var t2 = performance.now();
      var t3 = performance.now();

      // 4. Navigator client hints & mediaDevices
      var hasUAD = !!(navigator.userAgentData && navigator.userAgentData.brands.length > 0);
      var hasMedia = !!(navigator.mediaDevices && typeof navigator.mediaDevices.enumerateDevices === "function");

      JSON.stringify({
        toStringCallResult: toStringCallResult,
        nativeToStringName: nativeToStringName,
        vendor: vendor,
        renderer: renderer,
        extsCount: exts.length,
        hasInstanced: exts.indexOf("ANGLE_instanced_arrays") !== -1,
        px: Array.from(px),
        t1: t1,
        t2: t2,
        t3: t3,
        monotonic: (t3 >= t2) && (t2 >= t1),
        hasUAD: hasUAD,
        hasMedia: hasMedia
      });
    JS

    result = HttpMimic::JSRuntime.eval_json(test_script)
    assert_equal 'function createElement() { [native code] }', result['toStringCallResult']
    assert_equal 'toString', result['nativeToStringName']
    assert_equal 'Google Inc. (Intel)', result['vendor']
    assert_includes result['renderer'], 'ANGLE'
    assert result['extsCount'] >= 30
    assert result['hasInstanced']
    assert_equal [204, 102, 51, 255], result['px']
    assert result['monotonic']
    assert result['hasUAD']
    assert result['hasMedia']
  end

  def test_determine_profiles_respects_explicit_profile
    req = HttpMimic::Request.new('https://example.com', :get)
    assert_equal [:android], req.send(:determine_profiles, :auto, false, :android)
    assert_equal :android, req.send(:determine_profiles, :auto, true, :android).first

    assert_equal [:firefox], req.send(:determine_profiles, :auto, false, :firefox)
    assert_equal :firefox, req.send(:determine_profiles, :auto, true, :firefox).first
  end

  def test_akamai_solver_resolve_impersonate_target
    assert_equal 'chrome131_android', HttpMimic::Waf::AkamaiSolver.resolve_impersonate_target(:android)
    assert_equal 'safari260_ios', HttpMimic::Waf::AkamaiSolver.resolve_impersonate_target(:ios)
    assert_equal 'chrome150', HttpMimic::Waf::AkamaiSolver.resolve_impersonate_target(:impersonate)
  end

  def test_challenge_page_detection_on_200_response
    raw = "HTTP/2 200 OK\r\nset-cookie: _abck=123~-1\r\n\r\n<html><body><div id=\"sec-if-cpt-container\"></div></body></html>"
    resp = HttpMimic::ResponseParser.new(raw).parse
    assert_equal 200, resp.code
    assert resp.challenge_page?
    assert_equal :akamai, resp.challenge_type
  end

  def test_cookie_jar_and_script_src_in_browser_context
    context_js = File.read(File.expand_path('../lib/http_mimic/waf/browser_context.js', __dir__))
    script = <<~JS
      globalThis.__TARGET_URL__ = "https://example.com/products/test";
      globalThis.__DOCUMENT_TITLE__ = "";
      globalThis.__USER_AGENT__ = "Mozilla/5.0 Chrome/150";
      globalThis.__INITIAL_COOKIES__ = "geo_ip=1.2.3.4; bm_sz=abc~12345~6789";

      #{context_js}

      // 1. 測試 script.src 與 getAttribute
      const s = document.createElement("script");
      s.src = "https://example.com/cpt.js?v=1&t=9999";

      // 2. 測試 document.cookie 的追加寫入 (例如 CPT 寫入 bm_lso)
      document.cookie = "bm_lso=~99999; domain=.example.com; path=/";

      // 3. 測試 XMLHttpRequest responseURL
      const xhr = new XMLHttpRequest();
      xhr.open("POST", "/api/cpt");

      ({
        scriptPropSrc: s.src,
        scriptAttrSrc: s.getAttribute("src"),
        cookie: document.cookie,
        hasBmSz: document.cookie.includes("bm_sz=abc~12345~6789"),
        hasBmLso: document.cookie.includes("bm_lso=~99999"),
        xhrResponseURL: xhr.responseURL
      });
    JS

    res = HttpMimic.eval_js_json(script)
    assert_equal "https://example.com/cpt.js?v=1&t=9999", res["scriptPropSrc"]
    assert_equal "https://example.com/cpt.js?v=1&t=9999", res["scriptAttrSrc"]
    assert res["hasBmSz"], "bm_sz must be preserved after setting another cookie"
    assert res["hasBmLso"], "bm_lso must be recorded in cookieJar"
    assert_equal "https://example.com/api/cpt", res["xhrResponseURL"]
  end
end


