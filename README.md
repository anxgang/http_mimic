# HttpMimic

`http_mimic` is a Ruby HTTP Client gem built on top of `Open3.capture3` and `curl-impersonate`.
It provides an elegant, concise, and intuitive **HTTParty-style** API while leveraging [`lexiforest/curl-impersonate`](https://github.com/lexiforest/curl-impersonate) to simulate authentic Chrome, Firefox, Safari, Edge, and Tor TLS / HTTP2 fingerprints (JA3, JA4, Akamai) and handshakes.

It also includes **Webdrivers-like automatic driver management**, automatically downloading and managing `curl-impersonate` binaries across macOS, Linux, and Windows without manual setup.

---

## 🌟 Features

- **Webdrivers-Style Driver Management**:
  - Automatically downloads and unpacks official binaries from [`lexiforest/curl-impersonate`](https://github.com/lexiforest/curl-impersonate) to `~/.http_mimic/bin`.
  - **Automatic platform & architecture detection** (macOS ARM/Intel, Linux x86_64/aarch64/musl, Windows x86_64/arm64, FreeBSD).
  - Zero configuration required—installs on first request automatically.
  - Manual driver management helpers: `HttpMimic.download_driver!`, `HttpMimic.driver_installed?`, `HttpMimic::Downloader.available_binaries`.
- **Authentic Browser Handshakes & Fingerprints**:
  - Chrome support: `chrome131` (default), `chrome124`, `chrome120`, `chrome133a`, `chrome136`, `chrome142`, `chrome99-110`.
  - Firefox support: `firefox135`, `firefox133`, `firefox144`, `firefox117`, `firefox109`, `firefox102`, `firefox98`.
  - Safari support: `safari180`, `safari170`, `safari155`, `safari153`.
  - Edge & Tor support: `edge101`, `edge99`, `tor145`.
- **HTTParty-Style API**:
  - Direct module methods: `HttpMimic.get`, `HttpMimic.post`, etc.
  - Class mixin via `include HttpMimic` (`base_uri`, `headers`, `default_params`, `default_timeout`, `impersonate`, `proxy`, `cookies`, `persist_cookies`).
  - Reusable instance client: `HttpMimic::Client.new(...)`.
- **Zero Shell Injection Risk**:
  - Executes commands with array arguments via `Open3.capture3(*cmd_array)`.
  - Uses stdin streaming (`-d @-`) to safely handle large payloads without hitting OS command-line limits.
- **Smart Response Parsing**:
  - HTTP status helpers: `response.code`, `response.success?`, `response.redirect?`, `response.client_error?`, `response.server_error?`.
  - Case-insensitive header access: `response.headers['Content-Type']`.
  - Automatic `Set-Cookie` header parsing: `response.cookies['session_id']`.
  - Auto-parsed JSON with object delegation: `response['key']`, `response.parsed_response`.
  - Complete 3xx redirect history tracking: `response.history`.
- **Comprehensive Request Options**:
  - Supports `query`, `headers`, `json`, `body` (form data), `cookies`, `timeout`, `connect_timeout`, `proxy`, `basic_auth`, `digest_auth`, `bearer_token`, `insecure`, custom `curl_options`, and more.
- **Graceful Fallback**:
  - If a specific binary is unavailable and auto-download is disabled, automatically falls back to system standard `curl`.

---

## 📦 Installation

Add this line to your application's `Gemfile`:

```ruby
gem 'http_mimic'
```

And then execute:

```bash
bundle install
```

---

## 🤖 Driver Management

`HttpMimic` automatically downloads the corresponding platform binary of `curl-impersonate` on the first request and saves it to `~/.http_mimic/bin`.

You can also manage drivers manually:

```ruby
require 'http_mimic'

# Check if driver is installed locally
HttpMimic.driver_installed? # => true / false

# Manually trigger download (defaults to latest stable release v2.1.1)
HttpMimic.download_driver!

# Specify a version or force re-download
HttpMimic.download_driver!(version: 'v2.1.1', force: true)

# List all available browser binary names installed locally
HttpMimic::Downloader.available_binaries
# => ["curl_chrome131", "curl_chrome120", "curl_firefox135", "curl_safari180", ...]
```

---

## 🚀 Quick Start

### 1. Direct Module Calls

```ruby
require 'http_mimic'

# Send a GET request (simulates Chrome 131 fingerprint by default)
response = HttpMimic.get(
  'https://tls.browserleaks.com/json',
  impersonate: 'chrome131'
)

puts response.code                    # => 200
puts response.success?                 # => true
puts response['ja3_hash']             # => Authentic Chrome 131 JA3 fingerprint
puts response.headers['content-type'] # => "application/json"

# Send a POST JSON request (simulating Safari 18.0)
response = HttpMimic.post(
  'https://httpbin.org/post',
  json: { name: 'Alice', role: 'admin' },
  impersonate: 'safari180'
)

puts response.code            # => 200
puts response['json']['name'] # => "Alice"
```

---

### 2. Class Mixin Mode (HTTParty Style)

```ruby
class BrowserLeaksClient
  include HttpMimic

  base_uri 'https://tls.browserleaks.com'
  impersonate 'chrome120' # Default to Chrome 120
  default_timeout 30
  headers 'Accept-Language' => 'en-US,en;q=0.9'

  def test_fingerprint
    get('/json')
  end
end

client = BrowserLeaksClient.new
res = client.test_fingerprint

puts "HTTP Status: #{res.code}"
puts "JA3 Hash: #{res['ja3_hash']}"
puts "User-Agent: #{res['user_agent']}"
```

---

### 3. Instance Mode

```ruby
client = HttpMimic::Client.new(
  base_uri: 'https://api.example.com',
  mode: :auto,
  impersonate: 'firefox135',
  timeout: 15,
  headers: {
    'X-API-KEY' => 'my_api_key'
  }
)

# Execute GET
response = client.get('/v1/users', query: { limit: 10 })

# Execute POST
response = client.post('/v1/users', json: { username: 'bob' })
```

---

## 🧠 Smart Adaptive Modes (Zero-Configuration Scraping)

`HttpMimic` provides built-in multi-strategy orchestration so you can fetch protected websites without worrying about which specific WAF (Akamai Botman, Cloudflare Turnstile, DataDome, Kasada) protects them:

- **`:auto` (Default & Recommended)**: Tries desktop `curl-impersonate` (`chrome131`) first. If blocked by WAFs like Akamai with `403`/`429`/`503` (which require JS telemetry for desktop browsers), it **automatically cascades through mobile profiles (`android`, `ios`) and server `curl` headers**, reliably retrieving `200 OK`.
- **`:mobile_first` / `:android_first` / `:ios_first`**: Prefers mobile TLS/HTTP2 fingerprints and falls back to desktop or curl if blocked.
- **`:impersonate_first`**: Prefers desktop `curl-impersonate` and automatically falls back to mobile and curl if blocked.
- **`:curl_first`**: Prefers standard server `curl` and automatically upgrades to impersonate profiles if blocked.
- **`:impersonate_only` / `:mobile_only` / `:curl_only`**: Strictly uses the chosen profile (no fallback).

```ruby
# 1. No-Brain Auto Mode (Works automatically for Cloudflare, Akamai, etc.):
response = HttpMimic.get('https://www.adidas.com.hk/en/KI8139.html')
puts response.code                 # => 200
puts response.mode_used            # => :android
puts response.fallback_triggered?  # => true

# 2. Extract images and metadata with built-in helpers:
puts response.title                # => "SAMBA OG SHOES - Brown | adidas Hong Kong"
images = response.extract_images   # => ["https://assets.adidas.com/images/.../KI8139_01_00_standard.jpg", ...]

# 3. Fetch and save binary images directly:
HttpMimic.get(images.first).save('samba_og.jpg')
```

---

## 🍪 Persistent Host CookieStore

`HttpMimic` supports persistent host-based cookie caching. Once enabled, session and verification cookies are automatically saved to `~/.http_mimic/cookies/<host>.json` and reused in subsequent requests to the same host:

```ruby
# 1. Enable per-request
response = HttpMimic.get('https://example.com/items', persist_cookies: true)

# 2. Or enable in class mixin
class Scraper
  include HttpMimic
  persist_cookies true
  # persist_on_failure false # (default: do not save cookies on 403 / verification failure)
  # clear_on_failure true    # (default: auto-clear cached cookies if verification fails)
end

# 3. Manual CookieStore helpers
HttpMimic.load_cookies('example.com')                  # => Hash of active cookies
HttpMimic.save_cookies('example.com', { session: '123' }) # Save cookies with default TTL
HttpMimic.clear_cookies!('example.com')                # Clear host or all cookies
```

> **🛡️ Anti-Poisoning Failure Protection:**
> By default, `persist_on_failure` is set to `false`, meaning cookies returned with HTTP error codes (e.g. 403, 401) or unverified WAF challenge pages are **never** persisted to disk. Furthermore, `clear_on_failure: true` automatically wipes tainted host cookies upon verification failure, preventing blocked sessions from poisoning subsequent requests.

---

## 🧭 Target-Specific Navigation Headers & Client Hints

`HttpMimic` automatically constructs browser-accurate HTTP navigation headers on `GET` and `HEAD` requests:

- **Chrome Desktop / Mobile**: Generates `sec-ch-ua`, `sec-ch-ua-mobile`, `sec-ch-ua-platform`, and standard Chrome `Accept` headers.
- **Firefox & Safari / iOS**: **Strictly omits** Chromium-only `sec-ch-ua*` headers to prevent anti-bot detection and fingerprint mismatch anomalies.
- **Edge**: Generates Microsoft Edge brand `sec-ch-ua` headers.

Can be disabled globally with `config.navigation_headers = false` or per request via `navigation_headers: false`.

---

## ⚙️ Global Configuration

Configure global defaults in an initializer (e.g., `config/initializers/http_mimic.rb`):

```ruby
HttpMimic.configure do |config|
  # Multi-strategy & Smart Fallback
  config.mode                    = :auto       # :auto (default), :impersonate_first, :curl_first, :impersonate_only, :curl_only
  config.auto_fallback           = true        # Automatically retry with alternative profile if blocked
  config.retry_statuses          = [403, 429, 503] # Status codes that trigger auto-fallback

  # Browser simulation & request defaults
  config.default_impersonate     = 'chrome131' # Default browser target
  config.default_timeout         = 30          # Request timeout (seconds)
  config.default_connect_timeout = 10          # Connection timeout (seconds)
  config.follow_redirects        = true        # Automatically follow 3xx redirects
  config.max_redirects           = 10          # Maximum redirect limit
  config.fallback_to_curl        = true        # Fall back to system curl if binary is missing
  config.raise_on_error          = false       # Raise exceptions on HTTP errors / non-zero exits
  config.debug                   = false       # Print debug logs

  # Navigation headers & Client Hints simulation (enabled by default)
  config.navigation_headers      = true        # Browser-accurate sec-ch-ua, sec-fetch-*, Accept headers

  # Host CookieStore Persistence (disabled by default)
  config.persist_cookies         = false                                     # Auto-persist cookies per host
  config.cookie_store_dir        = File.expand_path('~/.http_mimic/cookies') # Directory for cookie store
  config.persist_on_failure      = false                                     # Do not save cookies if request/verification fails
  config.clear_on_failure        = true                                      # Purge cached host cookies on 403 / verification failure

  # WAF challenge solving (enabled by default)
  config.auto_solve_waf          = true        # Automatically solve detected WAF JS challenges

  # Webdrivers-like auto-download settings (enabled by default)
  config.auto_download           = true                                  # Auto-download missing binary
  config.driver_version          = 'v2.1.1'                              # Target release version
  config.install_dir             = File.expand_path('~/.http_mimic/bin') # Directory for binaries
  config.github_repo             = 'lexiforest/curl-impersonate'         # GitHub source repository
end
```

---

## 🛠️ Supported Request Options

| Option | Type | Description |
| :--- | :--- | :--- |
| `:mode` | Symbol | Execution strategy: `:auto` (default), `:impersonate_first`, `:curl_first`, `:impersonate_only`, `:curl_only` |
| `:auto_fallback` | Boolean | Whether to automatically retry with alternative profile on blocked status (default `true`) |
| `:retry_statuses`| Array | Status codes that trigger auto-fallback (default `[403, 429, 503]`) |
| `:impersonate` | String | Target browser to mimic (e.g., `'chrome131'`, `'chrome120'`, `'firefox135'`, `'safari180'`, `'tor145'`) |
| `:navigation_headers` | Boolean | Automatically generate browser-accurate navigation headers (`sec-ch-ua`, `sec-fetch-*`, `Accept`) (default `true`) |
| `:solve_waf` | Boolean | Automatically detect and solve WAF challenges (e.g. Akamai) via embedded QuickJS (default `true`) |
| `:binary` | String | Path to a custom `curl-impersonate` executable |
| `:query` / `:params` | Hash | URL query parameters (supports nested parameters and encoding) |
| `:headers` | Hash | Custom HTTP request headers |
| `:json` | Hash / Array | Serialized to JSON with `Content-Type: application/json` |
| `:body` | Hash / String | Form payload (Hash) or raw request body string |
| `:cookies` | Hash / String | Request cookies |
| `:persist_cookies` | Boolean | Automatically load and save cookies for the host across requests |
| `:persist_on_failure` | Boolean | Save cookies even if request or verification fails (default `false`) |
| `:clear_on_failure` | Boolean | Automatically clear stored cookies on verification failure / 403 / WAF block (default `true`) |
| `:cookie_jar` | String | Path to save cookies (`-c`) |
| `:cookie_file` | String | Path to read cookies (`-b`) |
| `:timeout` | Integer / Float | Maximum execution timeout in seconds (`--max-time`) |
| `:connect_timeout` | Integer / Float | Connection timeout in seconds (`--connect-timeout`) |
| `:proxy` | String | Proxy address (e.g., `'http://127.0.0.1:8888'`) |
| `:basic_auth` | Hash | `{ username: 'admin', password: 'secret' }` |
| `:bearer_token` | String | Appends `Authorization: Bearer <token>` header |
| `:insecure` | Boolean | Disable SSL certificate verification (`-k`) |
| `:curl_options` | Array / String | Additional raw curl arguments (e.g., `['--http2', '--compressed']`) |
| `:auto_render_spa` | Boolean | Automatically detect unhydrated SPA shells and render via Obscura |
| `:render` | Symbol | `:spa` or `:obscura` to explicitly render page via Obscura |

---

## ⚡ Obscura SPA Rendering (Tier 2 Engine)

`http_mimic` provides native support for [`h4ckf0r0day/obscura`](https://github.com/h4ckf0r0day/obscura)—a lightweight, single-binary (<100MB) headless browser engine written in Rust with an embedded V8 JavaScript runtime and built-in stealth anti-detection capabilities.

Obscura is auto-downloaded on-demand into `~/.http_mimic/bin/obscura` when SPA rendering is requested.

### 1. Automatic SPA Detection & Rendering (`auto_render_spa`)

Similar to `auto_solve_waf`, when `auto_render_spa: true` is enabled, `HttpMimic` first sends a microsecond-fast HTTP request (Tier 1). If the response is detected as an unhydrated SPA shell (empty React `#root`, Vue `#app`, Angular `<app-root>`, Google Dynamic SERP, or `<noscript>` prompt), it automatically transitions to Obscura (Tier 2) to render the full DOM tree:

```ruby
# Auto-detects SPA shell and seamlessly renders with Obscura
response = HttpMimic.get('https://example.com/spa', auto_render_spa: true)

puts response.code    # => 200
puts response.title   # => Fully hydrated DOM title
puts response.body    # => Fully rendered HTML with client-side injected DOM nodes
```

### 2. Direct SPA Rendering

```ruby
# Direct SPA render
response = HttpMimic.render('https://example.com/spa')

# or via alias:
response = HttpMimic.spa('https://example.com/spa')
```

**Supported Options**:
- `:wait_until` - `'load'`, `'domcontentloaded'`, `'networkidle0'` (default: `'networkidle0'`)
- `:timeout` - execution deadline in seconds (default: 30)
- `:proxy` - proxy address (`socks5://...` or `http://...`)
- `:eval` - JavaScript expression to evaluate in page context
- `:dump` - output format: `'html'` (default), `'text'`, `'links'`, `'markdown'`, `'cookies'`
- `:stealth` - whether stealth anti-detection is enabled (default: `true`)

---

## 📄 Response Object

The `Response` object wraps the HTTP response with convenient methods:

```ruby
response = HttpMimic.get('https://httpbin.org/get')

# Status information
response.code           # => 200 (Integer)
response.status         # => 200
response.status_message # => "OK"
response.http_version   # => "2"
response.success?       # => true (2xx)
response.redirect?      # => false (3xx)
response.client_error?  # => false (4xx)
response.server_error?  # => false (5xx)

# Response body & File operations
response.body           # => Raw Body (String / binary bytes)
response.binary?        # => true if content is an image, pdf, or binary stream
response.save('image.jpg') # => Directly saves response body to file
response.parsed_response# => Auto-parsed JSON Hash / Array
response['key']         # => Direct key access to parsed_response

# HTML & Scraping Helpers
response.title          # => HTML page title
response.og_image       # => OpenGraph image URL
response.meta_description # => Meta description
response.extract_images # => Array of all resolved image URLs in HTML

# Headers & Cookies
response.headers['content-type'] # => Case-insensitive header access
response.cookies['session_id']   # => Parsed Set-Cookie store
response.history                 # => Array of redirect history metadata

# Underlying execution & multi-strategy details
response.mode_used            # => :impersonate, :android, :ios, or :curl
response.fallback_triggered?  # => true if smart fallback was executed
response.attempts             # => Array of execution metadata for each attempt
response.exit_code            # => Process exit status (0 for success)
response.stderr               # => Stderr output from curl
response.command              # => Array of the exact CLI arguments executed
```

---

## 🧪 Testing

```bash
# Run offline unit tests
bundle exec rake test

# Run live integration tests against external TLS / JA3 / JA4 / Akamai endpoints
bundle exec rake test:live

# Run all tests
bundle exec rake test:all
```

---

## 📄 License

This project is available as open source under the terms of the [MIT License](file:///Users/ivan/work/Tranyi/_gem/http_mimic/LICENSE.txt).
Source code is hosted on [GitHub](https://github.com/anxgang/http_mimic).
