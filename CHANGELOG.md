# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-08-24

### Added
- **Initial Release of `HttpMimic`**: A HTTParty-like Ruby client wrapping `curl-impersonate` via `Open3.capture3`.
- **Core HTTP Verbs**: Support for `get`, `post`, `put`, `patch`, `delete`, `head`, and `options`.
- **Browser Fingerprint Impersonation**:
  - Support for `chrome116`, `chrome120`, `chrome110`, `chrome104`, `chrome101`, `chrome100`, `chrome99`.
  - Support for `firefox117`, `firefox109`, `firefox102`, `firefox98`.
  - Support for `safari15_5`, `safari15_3`.
  - Support for `edge101`, `edge99`.
  - Automatic fallback to system `curl` if specific impersonation binary is not found.
- **HTTParty-Style API**:
  - Direct module methods: `HttpMimic.get`, `HttpMimic.post`, etc.
  - Class-level DSL mixin via `include HttpMimic` (`base_uri`, `headers`, `default_params`, `default_timeout`, `impersonate`, `proxy`, `cookies`).
  - Reusable instance client: `HttpMimic::Client.new(...)`.
- **Smart Response & Parser**:
  - Auto-parsing JSON responses and method delegation (`response['key']`, `response.parsed_response`).
  - Case-insensitive header access (`response.headers['content-type']`).
  - Automatic `Set-Cookie` header parsing and cookie jar representation (`response.cookies`).
  - Complete 3xx redirect history tracking (`response.history`).
  - Rich status helpers (`response.success?`, `response.redirect?`, `response.client_error?`, `response.server_error?`, `response.ok?`).
- **Comprehensive Request Options**:
  - Query parameters (auto URL encoding and nested parameters).
  - Headers, JSON payloads (`json:`), Form URL-encoded data (`body:`), and Multipart (`form:` / `multipart:`).
  - Basic and Digest authentication (`basic_auth:`, `digest_auth:`, `bearer_token:`).
  - Timeouts (`timeout:`, `connect_timeout:`).
  - Proxy and Proxy authentication (`proxy:`, `proxy_auth:`).
  - SSL/TLS settings (`insecure:`, `ssl_ca_file:`, `ssl_cert:`, `ssl_key:`).
  - Raw curl arguments passthrough (`curl_options:`).
- **Safe CLI Execution**:
  - Uses array arguments in `Open3.capture3` to eliminate shell injection vulnerabilities.
  - Stdin streaming (`stdin_data`) with `-d @-` to bypass OS command line length limits for large payloads.
- **Unit Test Suite**:
  - Comprehensive tests for header handling, cookie parsing, command generation, response parsing, and redirect chains.
