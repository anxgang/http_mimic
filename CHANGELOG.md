# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.5] - 2026-09-05

### Fixed
- **QuickJS CPT & Bot Manager Telemetry Resolution (Tier 1 WAF Bypass)**:
  - **Standard `document.cookie` CookieJar**: Replaced the plain property in `browser_context.js` with a compliant `Map`-backed CookieJar. When Akamai CPT writes `document.cookie = "bm_lso=..."`, existing session cookies (`bm_sz`, `_abck`) are preserved rather than overwritten. This fixes the critical bug where main sensor telemetry fell back to default hash `8888888` instead of the session cookie hash.
  - **`HTMLScriptElement.src` Property Reflection**: Implemented bidirectional synchronization between `el.src` and `el.getAttribute("src")`. CPT scripts can now successfully inspect `document.currentScript.getAttribute("src")` to locate their challenge parameters and relative post endpoints.
  - **Accurate `document.currentScript` Execution Pipeline**: `AkamaiSolver.build_driver_script` now assigns `document.currentScript` before evaluating each script block, matching real browser multi-script execution order.
  - **Hybrid `XMLHttpRequest` with `responseURL` Support**: Retained instance-level methods (`open`, `send`) required by obfuscated Akamai scripts while maintaining prototype-level methods for DOM script hooks, and populating `responseURL` to allow `challenge.html` reload checks to succeed.
  - **Challenge Query String Preservation in Telemetry POST**: When sending CPT PoW solutions, `AkamaiSolver` now preserves query parameters (e.g. `v=...&t=...`) from the original challenge script URL so that edge servers correctly issue validated `bm_sc` session tokens.
- **End-to-End Akamai Verification**:
  - `HttpMimic.get('https://www.adidas.com/om/en/samba-og-shoes/KK2371.html')` now successfully solves the CPT challenge within QuickJS and returns the complete 400KB+ product HTML without invoking Tier 2 Obscura.

## [0.5.4] - 2026-09-05


### Fixed
- **Challenge Page Regression Prevention**:
  - `HttpMimic::Request` no longer preserves un-bypassed WAF challenge pages (such as Akamai 200 CPT skeletons) as `best_response`. If all resolution and fallback attempts fail, true status codes (e.g. 403) are preserved instead of overwriting with skeleton 200 responses.
- **Explicit Profile Forwarding in Fallbacks & Retries**:
  - `determine_profiles` now respects `explicit_profile = options[:profile]`, ensuring targeted profiles (e.g., `:android`) remain active when `auto_fallback: false` and are prioritized during fallback loops.
  - `AkamaiSolver` now explicitly forwards `profile` and concrete `impersonate` targets during final URL retries to prevent TLS/fingerprint mismatches.
- **Mobile/Android Emulation Fidelity in QuickJS Browser Polyfill**:
  - Fixed typo in Android platform identifier (`Linux armv8l` instead of `Linux armv81`).
  - Mobile environments now correctly emulate zero-length plugin and mimeType lists (removing desktop-only PDF plugins).
  - Aligned mobile screen dimensions (412x915 portrait-primary) and WebGL renderer parameters (Qualcomm Adreno 640).
- **Default Impersonate Profile Upgraded to `chrome150`**:
  - Upgraded default client TLS fingerprint to `chrome150` to satisfy modern Akamai edge HTTP/2 and TLS cipher requirements.
- **Modern CORS & Fetch Headers in Sensor POSTs**:
  - Automatically injected `Sec-Fetch-Dest: empty`, `Sec-Fetch-Mode: cors`, `Sec-Fetch-Site: same-origin`, and client hints (`sec-ch-ua`, `sec-ch-ua-mobile`, `sec-ch-ua-platform`).

## [0.5.3] - 2026-09-05

### Added
- **Automatic Free Proxy Pool (`auto_proxy`)**:
  - Built-in `HttpMimic::ProxyPool` automatically gathers and caches hundreds of public HTTP proxies from maintained sources (`monosans`, `proxyscrape`, `TheSpeedX`).
  - Disabled by default (`auto_proxy: false`) with per-request and global configuration opt-in.
  - Transparent proxy failure retry: automatically detects dead proxies (exit codes 5, 7, 28, 35, 56 or connection errors), marks them dead in the pool, and transparently retries with fresh proxies up to `proxy_retries` (default: 3).
  - Explicit manual `:proxy` option always takes precedence over `auto_proxy`.
  - Seamless integration with Obscura and WAF solver handshakes.
  - Added DSL helpers (`HttpMimic.auto_proxy`, `HttpMimic.proxy_pool`, `HttpMimic.refresh_proxies!`).
- **Streamlined Documentation**:
  - Refined README with concise, high-level highlights focusing on core anti-detect capabilities and developer experience.

## [0.5.2] - 2026-09-05

### Added
- **Anti-Poisoning Failure Protection for CookieStore (`persist_on_failure`, `clear_on_failure`)**:
  - `persist_on_failure` (default: `false`): Ensures failed/blocked requests (403, 401, retry statuses, or WAF challenge pages) do not save invalid or bot-flagged cookies to disk.
  - `clear_on_failure` (default: `true`): Automatically purges stored host cookies when a request fails verification or is blocked by WAF, preventing poisoned sessions from breaking subsequent requests.
  - Added class-level DSL and configuration support (`HttpMimic.persist_on_failure`, `HttpMimic.clear_on_failure`).
- **Two-Phase Telemetry Handshake in `AkamaiSolver`**:
  - Automatic multi-round telemetry loop sending second-stage interaction sensor posts after initial cookie acquisition to flip `_abck` tokens from `~-1~` to verified `~0~`.
- **Intelligent Profile Fallback & WAF Protection**:
  - `:auto` mode now rotates between distinct browser engines (`:impersonate` [Chrome], `:android`, `:ios`, `:firefox`) and skips plain `:curl` fallback on WAF targets to avoid IP flagging.
  - Added `:firefox` and `:safari` profile support in `CommandBuilder`.
  - Added Best Response Preservation: prevents successful/200 progress from being wiped out by later failed fallback attempts.

## [0.5.1] - 2026-08-30

### Added
- **Two-Phase Cookie & State Pipeline (Tier 1 ➔ Tier 2)**:
  - Automatically forward validated cookies (`NID`, `AEC`, `_abck`, `cf_clearance`) and custom headers from Tier 1 HTTP / WAF resolution directly into Obscura (`--cookie` flag) during `auto_render_spa` transitions.
- **Obscura Stealth BoringSSL Integration**:
  - Downloader now defaults to `*-stealth.tar.gz` release assets, equipping Obscura with native BoringSSL Chrome TLS / JA4 fingerprint impersonation.
- **Upgraded Obscura to `anxgang/obscura` v0.2.3**:
  - WebGL context, `REAL_FONT_METRICS` font measurements, and persistent Web Worker `importScripts` support.

## [0.5.0] - 2026-08-30

### Added
- **Tier 2: Obscura Headless SPA Rendering Support**:
  - Native integration with [`h4ckf0r0day/obscura`](https://github.com/h4ckf0r0day/obscura)—a lightweight (<100MB) Rust + V8 headless browser engine with built-in stealth anti-detection.
  - On-demand automatic driver management (`HttpMimic.download_obscura!`, `HttpMimic.obscura_installed?`, `HttpMimic.obscura_path`) across macOS (ARM64/x86_64), Linux (x86_64/aarch64), and Windows.
  - New rendering helpers: `HttpMimic.render(url, options = {})` and `HttpMimic.spa(url, options = {})`.
  - **Automatic SPA Detection & Transition (`auto_render_spa`)**:
    - Intelligent `HttpMimic::SpaDetector` detects unhydrated client-side SPA shells (React `#root`, Vue `#app`, Angular `<app-root>`, Google Dynamic SERP, `<noscript>` prompts).
    - When `auto_render_spa: true` (or `config.auto_render_spa = true`) is enabled, `HttpMimic.get` automatically transitions from Tier 1 (HTTP) to Tier 2 (Obscura) to render the full dynamic DOM.
  - Configurable options: `:wait_until` (`networkidle0`, `domcontentloaded`, `load`), `:timeout`, `:proxy`, `:eval`, `:dump`, `:selector`, `:user_agent`, and `:stealth`.

## [0.4.1] - 2026-08-30

### Added
- **Google Search Guard & BotGuard VM Detection**:
  - Added `HttpMimic::Waf::GoogleSolver` and `HttpMimic::Waf::Detector.google?` for detecting Google Search Guard (`knitsail`, `enablejs`, `SG_SS`) challenges.
  - Added automatic Google Search referral context (`Referer: https://www.google.com/`, `sec-fetch-site: same-origin`) in `CommandBuilder#apply_navigation_headers`.
- **Authentic Hardware & WebGL Pipeline Emulation in QuickJS Context**:
  - Full WebGL shader compilation and rasterization pipeline (`createShader`, `compileShader`, `getShaderPrecisionFormat`, `createProgram`, `linkProgram`, `readPixels` simulated gradient buffer).
  - Dynamic font measurement (`REAL_FONT_METRICS`) with exact macOS Chrome `offsetWidth` / `offsetHeight` dimensions across 17 font families and 7 font sizes.
  - Authentic Chromium `OfflineAudioContext` audio buffer rendering curve.
  - Physics-based Cubic Bézier Spline mouse movement simulation with velocity decay, natural micro-jitter, and complete click event chains.
  - Polyfills for `trustedTypes`, `sessionStorage`, `localStorage`, and `document.currentScript`.
- **Automatic Response Decompression**:
  - Added `--compressed` flag to CommandBuilder to ensure automatic transparent decompression of `gzip`, `deflate`, `br` (Brotli), and `zstd` payloads.

## [0.4.0] - 2026-08-30

### Added
- **Target-Specific Navigation Headers & Client Hints Simulation**:
  - Automatically generates browser-accurate Navigation Headers (`sec-fetch-dest`, `sec-fetch-mode`, `sec-fetch-site`, `upgrade-insecure-requests`) and Client Hints (`sec-ch-ua`, `sec-ch-ua-mobile`, `sec-ch-ua-platform`) tailored to the selected impersonation target.
  - Firefox (`firefox*`, `ff*`), Safari / iOS (`safari*`, `ios*`), and Tor targets strictly omit Chromium-only `sec-ch-ua*` headers to avoid anti-bot fingerprint anomalies and detection.
  - Android Chrome targets properly send `sec-ch-ua-mobile: ?1` and `sec-ch-ua-platform: "Android"`.
  - Edge targets properly send `"Microsoft Edge"` brand headers with `"Windows"` platform.
- **Unified Persistent CookieStore (`persist_cookies`)**:
  - Added `:persist_cookies` request option and `persist_cookies` class-level DSL method to automatically load and persist session cookies across requests per host into `~/.http_mimic/cookies/`.
  - Added helper methods: `HttpMimic.load_cookies(host, max_age: nil)`, `HttpMimic.save_cookies(host, cookies, ttl: nil)`, and `HttpMimic.clear_cookies!(host = nil)`.
- **WAF Challenge Solving & Fallback Performance Optimizations**:
  - Added single-pass WAF solver guard (`waf_solve_attempted`) to prevent redundant JavaScript solver executions across fallback attempts.
  - Added cross-attempt cookie accumulation to preserve session state between fallback profiles.
  - Added `HttpMimic::Waf::Detector.challenge_page?` to detect interstitial challenges disguised under HTTP 200 responses.

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
