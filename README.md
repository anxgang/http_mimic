# HttpMimic 🎭

> **Next-Generation Anti-Detect HTTP Client for Ruby**  
> An elegant, high-performance HTTP client combining authentic browser TLS/JA4 fingerprint impersonation, built-in anti-bot challenge solving, lightweight headless SPA rendering, and an automatic free proxy pool into an intuitive HTTParty-style API.

`http_mimic` provides a complete, modern toolchain for accessing protected endpoints and web scraping:
- **🎭 Authentic Browser Fingerprints**: Simulates authentic Chrome, Safari (macOS & iOS), Android, and Firefox TLS 1.3 / HTTP/2 handshakes and JA3/JA4 signatures.
- **🛡️ Built-in Anti-Bot Defense**: Automatically detects and solves advanced WAF challenges at microsecond speeds without the overhead of heavy browsers.
- **⚡ Dual-Tier Engine with Headless SPA Support**: Fast HTTP-first pipeline with seamless escalation to an embedded, lightweight (<100MB) Rust+V8 headless engine (`auto_render_spa`) when dynamic DOM rendering is needed.
- **🌐 Automatic Free Proxy Pool (`auto_proxy`)**: Built-in, zero-dependency proxy pool with health tracking, auto-rotation, and transparent failure retry.
- **🍪 Resilient Session Management**: Host-based persistent cookie caching with automatic anti-poisoning protection to prevent tainted sessions.
- **📦 Zero-Setup Driver Management**: Automatically provisions and manages required native binaries across macOS, Linux, and Windows on demand.
- **🚀 Intuitive Ruby DSL**: Clean, idiomatic syntax supporting class mixins (`include HttpMimic`), direct module calls (`HttpMimic.get`), and reusable client instances.

---

## 🌟 Highlights

- **Authentic TLS & HTTP/2 Impersonation**: Native support for `chrome131` (default), `chrome120-142`, `safari180` (macOS/iOS), `firefox135`, `edge101`, and `tor145`.
- **Intelligent Challenge Resolution**: Automatic WAF challenge mitigation and smart profile fallback to keep requests succeeding.
- **Client-Side SPA Hydration**: High-speed HTTP execution by default, with optional V8 DOM hydration for complex JavaScript apps (`auto_render_spa: true`).
- **Free Proxy Pool & Auto-Rotation**: Opt-in proxy management (`auto_proxy: true`) with automatic dead-proxy detection and retry.
- **Safe & Reliable**: Zero shell injection risk via `Open3.capture3(*cmd_array)`, safe stdin streaming for large payloads, and smart response parsing.
- **Flexible Integration**: Works seamlessly as a one-off client, a reusable instance, or a class-level DSL.

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
| `:auto_proxy` | Boolean | Automatically fetch and rotate through a pool of free HTTP proxies (default: `false`) |
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

## 🌐 Automatic Free Proxy Pool (`auto_proxy`)

`http_mimic` provides a built-in, zero-dependency Free Proxy Pool manager. When enabled, `HttpMimic` automatically fetches and pools hundreds of free HTTP proxies from maintained public sources (monosans, ProxyScrape, TheSpeedX), automatically marks dead proxies, and transparently retries requests on network or proxy failure.

By default, `auto_proxy` is **`false`** so users can choose when to opt-in.

### 1. Per-Request Opt-in

```ruby
# Automatically obtain a proxy from the pool and execute request
response = HttpMimic.get('https://httpbin.org/ip', auto_proxy: true)

# Explicit proxy always takes precedence over auto_proxy:
response = HttpMimic.get('https://httpbin.org/ip', auto_proxy: true, proxy: 'http://my-dedicated-proxy:8080')
```

### 2. Global Configuration

```ruby
HttpMimic.configure do |config|
  config.auto_proxy = true          # Enable free proxy pool by default
  config.proxy_retries = 3          # Maximum proxy retry attempts on connection failure
  config.proxy_pool_ttl = 1800      # Cache duration for fetched proxy list (seconds)
end

# Or via class-level DSL:
HttpMimic.auto_proxy = true
```

### 3. Proxy Pool Management

```ruby
# Check available pool size
HttpMimic.proxy_pool.size

# Sample a random proxy from the pool
HttpMimic.proxy_pool.sample # => "http://185.200.188.234:10001"

# Manually refresh the proxy pool
HttpMimic.refresh_proxies!

# Load custom proxies into the pool
HttpMimic.proxy_pool.load(['http://1.2.3.4:8080', 'http://5.6.7.8:3128'])
```

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
