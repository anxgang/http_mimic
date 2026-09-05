# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/http_mimic'

class ProxyPoolTest < Minitest::Test
  def setup
    HttpMimic.reset_configuration!
    HttpMimic::ProxyPool.clear!
  end

  def teardown
    HttpMimic::ProxyPool.clear!
  end

  def test_configuration_defaults
    config = HttpMimic.configuration
    refute config.auto_proxy
    assert_nil config.proxy_sources
    assert_equal 3, config.proxy_retries
    assert_equal 1800, config.proxy_pool_ttl
    assert_equal 5, config.proxy_timeout
  end

  def test_dsl_methods
    refute HttpMimic.auto_proxy
    HttpMimic.auto_proxy(true)
    assert HttpMimic.auto_proxy

    HttpMimic.proxy_sources(['https://example.com/proxies.txt'])
    assert_equal ['https://example.com/proxies.txt'], HttpMimic.proxy_sources
  end

  def test_proxy_pool_load_and_sample
    pool = HttpMimic::ProxyPool.instance
    pool.load(['1.2.3.4:8080', 'http://5.6.7.8:3128'])

    assert_equal 2, pool.size
    assert_includes ['http://1.2.3.4:8080', 'http://5.6.7.8:3128'], pool.get
  end

  def test_proxy_pool_mark_dead_and_alive
    pool = HttpMimic::ProxyPool.instance
    pool.load(['1.1.1.1:80', '2.2.2.2:80'])

    pool.mark_dead('1.1.1.1:80')
    assert_equal 1, pool.size
    assert_equal 'http://2.2.2.2:80', pool.get
    assert_includes pool.dead_proxies, 'http://1.1.1.1:80'

    pool.mark_alive('1.1.1.1:80')
    assert_equal 2, pool.size
  end

  def test_auto_proxy_assigns_proxy_to_request
    pool = HttpMimic::ProxyPool.instance
    pool.load(['10.0.0.1:8080'])

    req = HttpMimic::Request.new(:get, 'https://example.com', auto_proxy: true)
    status_0 = Struct.new(:exitstatus).new(0)
    executed_commands = []

    req.define_singleton_method(:execute_open3) do |cmd, stdin|
      executed_commands << cmd
      ["HTTP/2 200 OK\r\n\r\nOK", '', status_0]
    end

    resp = req.perform
    assert_equal 200, resp.code
    cmd = executed_commands.first.join(' ')
    assert_includes cmd, '-x http://10.0.0.1:8080'
  end

  def test_explicit_proxy_takes_precedence_over_auto_proxy
    pool = HttpMimic::ProxyPool.instance
    pool.load(['10.0.0.1:8080'])

    req = HttpMimic::Request.new(:get, 'https://example.com', auto_proxy: true, proxy: 'http://custom-proxy:9999')
    status_0 = Struct.new(:exitstatus).new(0)
    executed_commands = []

    req.define_singleton_method(:execute_open3) do |cmd, stdin|
      executed_commands << cmd
      ["HTTP/2 200 OK\r\n\r\nOK", '', status_0]
    end

    req.perform
    cmd = executed_commands.first.join(' ')
    assert_includes cmd, '-x http://custom-proxy:9999'
    refute_includes cmd, '10.0.0.1:8080'
  end

  def test_auto_proxy_retries_on_proxy_failure
    pool = HttpMimic::ProxyPool.instance
    pool.load(['10.0.0.1:8080', '10.0.0.2:8080'])

    req = HttpMimic::Request.new(:get, 'https://example.com', auto_proxy: true, auto_fallback: false)
    call_count = 0
    executed_proxies = []

    req.define_singleton_method(:execute_open3) do |cmd, stdin|
      call_count += 1
      cmd_str = cmd.join(' ')
      proxy = cmd_str.match(/-x (http:\/\/[^\s]+)/)&.[](1)
      executed_proxies << proxy

      if call_count == 1
        # First call with 10.0.0.1 fails with curl exit code 7 (Failed to connect to proxy)
        err_status = Struct.new(:exitstatus).new(7)
        ['', 'curl: (7) Failed to connect to proxy', err_status]
      else
        # Second call succeeds
        ok_status = Struct.new(:exitstatus).new(0)
        ["HTTP/2 200 OK\r\n\r\nSuccess via proxy", '', ok_status]
      end
    end

    resp = req.perform
    assert_equal 200, resp.code
    assert_equal 2, call_count
    # Verified that dead proxy was marked
    assert_includes pool.dead_proxies, executed_proxies.first
  end

  def test_auto_proxy_disabled_by_default
    pool = HttpMimic::ProxyPool.instance
    pool.load(['10.0.0.1:8080'])

    req = HttpMimic::Request.new(:get, 'https://example.com')
    status_0 = Struct.new(:exitstatus).new(0)
    executed_commands = []

    req.define_singleton_method(:execute_open3) do |cmd, stdin|
      executed_commands << cmd
      ["HTTP/2 200 OK\r\n\r\nOK", '', status_0]
    end

    req.perform
    cmd = executed_commands.first.join(' ')
    refute_includes cmd, '-x'
  end

  def test_fetch_from_sources_parses_ip_port_list
    pool = HttpMimic::ProxyPool.new(sources: ['https://mock.example.com/http.txt'])
    mock_body = "192.168.1.1:8080\n203.0.113.5:3128\nsome invalid line\n10.0.0.1:9050"

    mock_resp = Net::HTTPSuccess.new('1.1', '200', 'OK')
    mock_resp.define_singleton_method(:body) { mock_body }

    old_new = Net::HTTP.method(:new)
    singleton = Net::HTTP.singleton_class
    old_verbose = $VERBOSE
    $VERBOSE = nil
    singleton.send(:define_method, :new) do |*args|
      http = Object.new
      http.define_singleton_method(:use_ssl=) { |_| }
      http.define_singleton_method(:open_timeout=) { |_| }
      http.define_singleton_method(:read_timeout=) { |_| }
      http.define_singleton_method(:request) { |_| mock_resp }
      http
    end
    $VERBOSE = old_verbose

    begin
      proxies = pool.send(:fetch_from_sources)
      assert_equal ['http://192.168.1.1:8080', 'http://203.0.113.5:3128', 'http://10.0.0.1:9050'], proxies
    ensure
      $VERBOSE = nil
      singleton.send(:define_method, :new, old_new)
      $VERBOSE = old_verbose
    end
  end

  def test_obscura_auto_proxy_forwarding
    pool = HttpMimic::ProxyPool.instance
    pool.load(['10.0.0.5:8080'])

    captured_opts = nil
    old_render = HttpMimic::Obscura.method(:render)
    singleton = HttpMimic::Obscura.singleton_class
    old_verbose = $VERBOSE
    $VERBOSE = nil
    singleton.send(:define_method, :render) do |url, opts|
      captured_opts = opts
      HttpMimic::Response.new(code: 200, status_message: 'OK', headers: {}, body: 'SPA OK', cookies: {})
    end
    $VERBOSE = old_verbose

    begin
      HttpMimic.get('https://example.com/spa', render: :spa, auto_proxy: true)
    ensure
      $VERBOSE = nil
      singleton.send(:define_method, :render, old_render)
      $VERBOSE = old_verbose
    end

    assert captured_opts
    assert_equal 'http://10.0.0.5:8080', captured_opts[:proxy]
  end
end
