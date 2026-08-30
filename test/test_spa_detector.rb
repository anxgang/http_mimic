# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/http_mimic'

class SpaDetectorTest < Minitest::Test
  def make_response(body, content_type: 'text/html; charset=utf-8', code: 200)
    HttpMimic::Response.new(
      code: code,
      http_version: 'HTTP/2',
      status_message: 'OK',
      headers: HttpMimic::Headers.new({ 'content-type' => content_type }),
      cookies: HttpMimic::Cookies.new,
      body: body,
      parsed_response: nil,
      raw_headers: "HTTP/2 #{code} OK\r\ncontent-type: #{content_type}\r\n\r\n",
      history: [],
      request_url: 'https://example.com',
      stderr: '',
      exit_code: 0,
      command: 'mock'
    )
  end

  def test_detects_empty_react_root
    html = '<!DOCTYPE html><html><head><title>React App</title></head><body><div id="root"></div><script src="/bundle.js"></script></body></html>'
    resp = make_response(html)
    assert HttpMimic::SpaDetector.spa?(resp)
    assert HttpMimic.spa?(resp)
  end

  def test_detects_empty_vue_app
    html = '<!DOCTYPE html><html><head><title>Vue App</title></head><body><div id="app"> </div><script src="/app.js"></script></body></html>'
    resp = make_response(html)
    assert HttpMimic::SpaDetector.spa?(resp)
  end

  def test_detects_empty_angular_app_root
    html = '<!DOCTYPE html><html><head><title>Angular</title></head><body><app-root></app-root><script src="/main.js"></script></body></html>'
    resp = make_response(html)
    assert HttpMimic::SpaDetector.spa?(resp)
  end

  def test_detects_empty_nextjs_mount
    html = '<!DOCTYPE html><html><head></head><body><div id="__next"></div><script src="/_next/static.js"></script></body></html>'
    resp = make_response(html)
    assert HttpMimic::SpaDetector.spa?(resp)
  end

  def test_detects_noscript_requirement
    html = '<!DOCTYPE html><html><body><noscript>You need to enable JavaScript to run this app.</noscript><script src="/app.js"></script></body></html>'
    resp = make_response(html)
    assert HttpMimic::SpaDetector.spa?(resp)
  end

  def test_detects_google_serp_shell
    html = '<!DOCTYPE html><html><head><title>Google</title></head><body><script src="/httpservice/retry/enablejs?id=123"></script></body></html>'
    resp = make_response(html)
    assert HttpMimic::SpaDetector.spa?(resp)
  end

  def test_ignores_populated_ssr_html
    html = '<!DOCTYPE html><html><head><title>Article Title</title></head><body><article><h1>Deep Dive</h1><p>' + ('Lots of rich content text ' * 30) + '</p></article></body></html>'
    resp = make_response(html)
    refute HttpMimic::SpaDetector.spa?(resp)
  end

  def test_ignores_non_html_and_error_responses
    json_resp = make_response('{"status":"ok"}', content_type: 'application/json')
    refute HttpMimic::SpaDetector.spa?(json_resp)

    err_resp = make_response('<div id="root"></div>', code: 500)
    refute HttpMimic::SpaDetector.spa?(err_resp)
  end
end
