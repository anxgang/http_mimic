# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-08-24

### Added
- **Webdrivers-like Auto Driver Management (`HttpMimic::Downloader`)**:
  - Automatically downloads and unpacks official binaries from [`lexiforest/curl-impersonate`](https://github.com/lexiforest/curl-impersonate) releases to `~/.http_mimic/bin`.
  - Automatic platform detection for macOS (ARM64 / x86_64), Linux (GNU / MUSL, x86_64, aarch64, arm, i386, riscv64, loongarch64), Windows (x86_64, arm64, i686), and FreeBSD.
  - Manual driver management helpers: `HttpMimic.download_driver!`, `HttpMimic.driver_installed?`, `HttpMimic::Downloader.available_binaries`.
  - Configurable auto-download, target release version, install directory, and custom GitHub repo.
- **Expanded Browser Target Support**:
  - Support for Chrome (`chrome116`, `chrome120`, `chrome123`, `chrome124`, `chrome131`, `chrome133a`, `chrome136`, `chrome142`, `chrome99-110`).
  - Support for Firefox (`firefox133`, `firefox135`, `firefox144`, `firefox117`, `firefox109`, `firefox102`, `firefox98`).
  - Support for Safari (`safari180`, `safari170`, `safari155`, `safari153`).
  - Support for Edge (`edge101`, `edge99`) and Tor (`tor145`).

## [0.1.0] - 2026-08-24

### Added
- **Initial Release of `HttpMimic`**: A HTTParty-like Ruby client wrapping `curl-impersonate` via `Open3.capture3`.
- **Core HTTP Verbs**: Support for `get`, `post`, `put`, `patch`, `delete`, `head`, and `options`.
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
  - Comprehensive tests for header handling, cookie parsing, command generation, response parsing, redirect chains, and platform slug detection.
