# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/http_mimic'

class HttpMimicTest < Minitest::Test
  def setup
    HttpMimic.reset_configuration!
  end

  def test_version
    refute_nil HttpMimic::VERSION
  end

  def test_headers_case_insensitivity
    headers = HttpMimic::Headers.new('Content-Type' => 'application/json', 'X-Custom-Header' => 'value123')
    
    assert_equal 'application/json', headers['content-type']
    assert_equal 'application/json', headers['Content-Type']
    assert_equal 'application/json', headers['CONTENT-TYPE']
    assert_equal 'value123', headers['x-custom-header']
    assert headers.key?('content-type')
    assert headers.key?('Content-Type')
  end

  def test_multi_value_headers_and_set_cookie
    headers = HttpMimic::Headers.new
    headers.add('Set-Cookie', 'session=abc; Path=/')
    headers.add('Set-Cookie', 'remember_me=1; Path=/')

    assert_equal ['session=abc; Path=/', 'remember_me=1; Path=/'], headers.get_all('set-cookie')
  end

  def test_cookies_parsing
    cookies = HttpMimic::Cookies.parse_set_cookie([
      'session=abc123xyz; Path=/; HttpOnly; Secure',
      'user_id=42; Domain=.example.com'
    ])

    assert_equal 'abc123xyz', cookies['session']
    assert_equal '42', cookies['user_id']
    assert_equal 'session=abc123xyz; user_id=42', cookies.to_cookie_string
    assert_equal 'session=abc123xyz; user_id=42', HttpMimic::Cookies.format(cookies)
  end

  def test_command_builder_args
    builder = HttpMimic::CommandBuilder.new(
      :post,
      'https://api.example.com/items',
      {
        query: { page: 1, filter: 'active' },
        headers: { 'Authorization' => 'Bearer token123' },
        json: { name: 'Test Item', price: 100 },
        timeout: 15,
        connect_timeout: 5,
        follow_redirects: true,
        max_redirects: 5,
        insecure: true,
        user_agent: 'CustomUA/1.0',
        cookies: { test_cookie: 'yes' }
      }
    )

    binary, args, stdin_data, final_url = builder.build

    assert_includes ['curl', 'curl_chrome131', 'curl_chrome116', 'curl-impersonate-chrome'], File.basename(binary)
    assert_includes args, '-s'
    assert_includes args, '-i'
    assert_includes args, '-X'
    assert_includes args, 'POST'
    assert_includes args, '-L'
    assert_includes args, '--max-redirs'
    assert_includes args, '5'
    assert_includes args, '--max-time'
    assert_includes args, '15'
    assert_includes args, '--connect-timeout'
    assert_includes args, '5'
    assert_includes args, '-k'
    assert_includes args, '-A'
    assert_includes args, 'CustomUA/1.0'
    assert_includes args, '-b'
    assert_includes args, 'test_cookie=yes'
    assert_includes args, '-H'
    assert_includes args, 'Authorization: Bearer token123'
    assert_includes args, 'Content-Type: application/json'
    assert_includes args, '-d'
    assert_includes args, '@-'
    
    assert_equal '{"name":"Test Item","price":100}', stdin_data
    assert_equal 'https://api.example.com/items?page=1&filter=active', final_url
    assert_equal final_url, args.last
  end

  def test_response_parser_single_response
    raw = "HTTP/2 200 \r\ncontent-type: application/json\r\nserver: nginx\r\n\r\n{\"success\":true,\"id\":123}"
    parser = HttpMimic::ResponseParser.new(raw)
    response = parser.parse

    assert_equal 200, response.code
    assert_equal 200, response.status
    assert response.success?
    assert response.ok?
    refute response.error?
    assert_equal '2', response.http_version
    assert_equal 'application/json', response.headers['content-type']
    assert_equal 'nginx', response.headers['Server']
    assert_equal({ 'success' => true, 'id' => 123 }, response.parsed_response)
    assert_equal true, response['success']
    assert_equal 123, response['id']
  end

  def test_response_parser_redirect_chain
    raw = <<~RAW
      HTTP/1.1 301 Moved Permanently
      Location: https://example.com/v2

      HTTP/1.1 302 Found
      Location: https://example.com/v2/items

      HTTP/2 200 OK
      Content-Type: text/plain; charset=utf-8

      Hello Impersonate
    RAW

    parser = HttpMimic::ResponseParser.new(raw)
    response = parser.parse

    assert_equal 200, response.code
    assert_equal 'OK', response.status_message
    assert_equal 2, response.history.size
    assert_equal 301, response.history[0][:code]
    assert_equal 302, response.history[1][:code]
    assert_equal 'Hello Impersonate', response.body.strip
    assert_equal 'Hello Impersonate', response.to_s.strip
  end

  def test_client_class_dsl
    klass = Class.new do
      include HttpMimic

      base_uri 'https://httpbin.org'
      default_timeout 25
      headers 'X-App-Name' => 'Tester'
      impersonate 'chrome116'
    end

    assert_equal 'https://httpbin.org', klass.base_uri
    assert_equal 25, klass.default_options[:timeout]
    assert_equal 'chrome116', klass.default_options[:impersonate]
    assert_equal({ 'X-App-Name' => 'Tester' }, klass.default_options[:headers])
  end

  def test_client_instance
    client = HttpMimic::Client.new(
      base_uri: 'https://example.com',
      headers: { 'X-Secret' => 'abc' },
      timeout: 10
    )

    assert_equal 'https://example.com', client.default_options[:base_uri]
    assert_equal 10, client.default_options[:timeout]
  end

  def test_downloader_platform_slug
    slug = HttpMimic::Downloader.platform_slug
    refute_nil slug
    assert_match(/(macos|linux|win32|freebsd)/, slug)
  end

  def test_downloader_installed_check
    assert [true, false].include?(HttpMimic::Downloader.installed?)
  end
end
