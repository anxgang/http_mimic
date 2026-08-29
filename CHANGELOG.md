# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.2] - 2026-08-29

### Added
- **Mobile Impersonation & Multi-Stage Auto-Fallback**:
  - Added support for mobile browser targets: Android Chrome (`chrome131_android`, `chrome99_android`, alias `android`) and iOS Safari (`safari260_ios`, `safari180_ios`, `safari184_ios`, `safari172_ios`, alias `ios`, `mobile`).
  - Enhanced `:auto` adaptive mode with automatic fallback cascade `[:impersonate, :android, :ios, :curl]` to bypass modern anti-bot systems (e.g. Akamai Bot Manager on Adidas HK) without requiring JavaScript telemetry solving.
  - Added execution modes: `:mobile_first`, `:android_first`, `:ios_first`, `:mobile_only`, `:android_only`, `:ios_only`.
- **Binary-Safe Response Parsing & File Saving**:
  - Fixed binary handling in `ResponseParser#split_headers_and_body` to prevent `ArgumentError: invalid byte sequence in UTF-8` on images, PDFs, compressed files, and binary streams.
  - Added `response.binary?` and `response.save_to_file(path)` / `response.save(path)` helpers.
- **Built-in HTML / Scraping Helpers**:
  - Added `response.title`, `response.og_image`, `response.meta_description`, and `response.extract_images(base_url: nil)`.

## [0.3.1] - 2026-08-25

### Added
- **Smart Adaptive Multi-Strategy Modes (`:auto`, `:impersonate_first`, `:curl_first`, `:impersonate_only`, `:curl_only`)**:
  - **Zero-Configuration Protection Bypass (`:auto` mode, enabled by default)**: Seamlessly tries `curl-impersonate` first, and if blocked by WAFs with `403`/`429`/`503` (e.g. Akamai bot challenges requiring JS), automatically falls back to standard `curl` with server client headers to reliably retrieve 200 OK.
  - Per-request and class-level configurable execution mode (`mode:`, `auto_fallback:`, `retry_statuses:`).
  - Enhanced `Response` object with `response.mode_used`, `response.fallback_triggered?`, and `response.attempts` metadata.
  - Added live integration test for Akamai-protected site bypass (`test_smart_auto_fallback_on_akamai_protected_site`).

## [0.3.0] - 2026-08-24

### Added
- **Live Fingerprint Test Suite**: Added integration tests (`rake test:live`) verifying real-world JA3, JA4, and Akamai HTTP/2 fingerprints against live endpoints (`tls.browserleaks.com`, `tls.peet.ws`).
- **Standard MIT License**: Included official `LICENSE.txt` and repository metadata.
- **Rakefile Integration**: Added standard Rake test tasks for unit tests, live tests, and full test suites.

### Changed
- **Default Impersonation Target**: Upgraded default impersonation from `chrome116` to modern `chrome131` with Post-Quantum (ML-KEM) and modern Client Hints support.
- **Internationalization**: Fully translated all code comments, error messages, and documentation into English.

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
