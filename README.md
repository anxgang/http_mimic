# HttpMimic

`http_mimic` 是一個基於 `Open3.capture3` 與 `curl-impersonate` 的 Ruby HTTP Client Gem。
它的目標是提供類似 **HTTParty** 那樣優雅、簡潔、直覺的語法，同時具備 `curl-impersonate` 模擬真實 Chrome / Firefox / Safari / Edge 的 TLS / HTTP2 指紋（Fingerprint）與握手能力。

---

## 🌟 特色

- **HTTParty 風格 API**：支援 `HttpMimic.get`、`HttpMimic.post`、類別 Mixin (`include HttpMimic`) 與實例化 `HttpMimic::Client.new`。
- **真實瀏覽器握手與指紋模擬**：支援指定 `impersonate: 'chrome116'`、`'chrome120'`、`'firefox117'` 等目標瀏覽器。
- **無 Shell 注入風險**：使用 `Open3.capture3(*cmd_array)` 以陣列參數執行，安全可靠。
- **自動解析 HTTP 回應**：
  - HTTP 狀態碼 (`response.code`、`response.success?`、`response.status_message`)
  - 不區分大小寫的 Header 存取 (`response.headers['Content-Type']`)
  - Set-Cookie 自動解析 (`response.cookies['session_id']`)
  - JSON 自動反序列化與物件委派 (`response['key']`、`response.parsed_response`)
  - Redirect 歷史紀錄追蹤 (`response.history`)
- **完整的請求選項**：支援 `query`、`headers`、`json`、`body` (form data)、`cookies`、`timeout`、`proxy`、`basic_auth`、`bearer_token`、`insecure`、自訂 `curl_options` 等。
- **自動退回機制 (Graceful Fallback)**：當系統尚未安裝特定版本 `curl-impersonate` 執行檔時，預設自動退回至系統標準 `curl`，方便開發與測試。

---

## 📦 安裝與引入

在 Rails 專案的 `Gemfile` 中加入：

```ruby
gem 'http_mimic'
```

接著執行：

```bash
bundle install
```

---

## 🚀 快速上手

### 1. 直接呼叫模組方法 (Direct Calls)

```ruby
require 'http_mimic'

# 發送 GET 請求
response = HttpMimic.get(
  'https://httpbin.org/get',
  query: { category: 'ruby', page: 1 },
  headers: { 'Authorization' => 'Bearer secret_token' },
  impersonate: 'chrome116' # 指定模擬 Chrome 116
)

puts response.code            # => 200
puts response.success?         # => true
puts response.headers['content-type'] # => "application/json"
puts response['args']         # => { "category" => "ruby", "page" => "1" }

# 發送 POST JSON 請求
response = HttpMimic.post(
  'https://httpbin.org/post',
  json: { name: 'Alice', role: 'admin' }
)

puts response.code            # => 200
puts response['json']['name'] # => "Alice"
```

---

### 2. 類別 Mixin 模式 (HTTParty Style)

```ruby
class BrowserLeaksClient
  include HttpMimic

  base_uri 'https://tls.browserleaks.com'
  impersonate 'chrome116' # 預設模擬 Chrome
  default_timeout 30
  headers 'Accept-Language' => 'zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7'

  def test_ja3_fingerprint
    get('/json')
  end
end

client = BrowserLeaksClient.new
res = client.test_ja3_fingerprint

puts "HTTP Status: #{res.code}"
puts "JA3 Hash: #{res['ja3_hash']}"
puts "User-Agent: #{res['user_agent']}"
```

---

### 3. Client 實例化模式 (Instance Mode)

```ruby
client = HttpMimic::Client.new(
  base_uri: 'https://api.example.com',
  impersonate: 'chrome120',
  timeout: 15,
  headers: {
    'X-API-KEY' => 'my_api_key'
  }
)

# 執行 GET
response = client.get('/v1/users', query: { limit: 10 })

# 執行 POST
response = client.post('/v1/users', json: { username: 'bob' })
```

---

## ⚙️ 全域配置 (Configuration)

可在 Rails 初始化檔（如 `config/initializers/http_mimic.rb`）中設定全域預設值：

```ruby
HttpMimic.configure do |config|
  config.default_impersonate     = 'chrome116' # 預設模擬目標
  config.default_timeout         = 30          # 預設 Timeout (秒)
  config.default_connect_timeout = 10          # 預設連線 Timeout (秒)
  config.follow_redirects        = true        # 自動追蹤 3xx 轉址
  config.max_redirects           = 10          # 最大轉址次數
  config.fallback_to_curl        = true        # 找不到 impersonate binary 時退回系統 curl
  config.raise_on_error          = false       # 是否在 HTTP 錯誤或連線失敗時拋出例外
  config.debug                   = false       # 是否輸出除錯日誌
end
```

---

## 🛠️ 支援的 HTTP Verbs 與選項

### 支援的方法
- `get(url, options = {})`
- `post(url, options = {})`
- `put(url, options = {})`
- `patch(url, options = {})`
- `delete(url, options = {})`
- `head(url, options = {})`
- `options(url, options = {})`

### 常用 Options
| Option | 類型 | 說明 |
| :--- | :--- | :--- |
| `:impersonate` | String | 模擬目標，例如 `'chrome116'`, `'chrome120'`, `'firefox117'`, `'safari15_5'` |
| `:binary` | String | 指定自訂的 curl-impersonate 執行檔路徑 |
| `:query` / `:params` | Hash | URL 查詢參數（自動處理巢狀結構與編碼） |
| `:headers` | Hash | 自訂 Request Headers |
| `:json` | Hash / Array | 自動轉為 JSON 字串並附加 `Content-Type: application/json` |
| `:body` | Hash / String | Form 資料（Hash）或 Raw Body 字串 |
| `:cookies` | Hash / String | 攜帶的 Cookie |
| `:cookie_jar` | String | 儲存 Cookie 的檔案路徑 (`-c`) |
| `:cookie_file` | String | 讀取 Cookie 的檔案路徑 (`-b`) |
| `:timeout` | Integer / Float | 最大執行時間 (`--max-time`) |
| `:connect_timeout` | Integer / Float | 連線建立超時 (`--connect-timeout`) |
| `:proxy` | String | Proxy 位址，如 `'http://127.0.0.1:8888'` |
| `:basic_auth` | Hash | `{ username: 'admin', password: 'secret' }` |
| `:bearer_token` | String | 自動附加 `Authorization: Bearer <token>` |
| `:insecure` | Boolean | 忽略 SSL 憑證檢查 (`-k`) |
| `:curl_options` | Array / String | 額外的原生 curl 參數（如 `['--http2', '--compressed']`） |

---

## 📄 回應物件 (Response Object)

`Response` 提供豐富的屬性與便利的方法：

```ruby
response = HttpMimic.get('https://httpbin.org/get')

# 狀態資訊
response.code           # => 200 (Integer)
response.status         # => 200
response.status_message # => "OK"
response.http_version   # => "2"
response.success?       # => true (2xx)
response.redirect?      # => false (3xx)
response.client_error?  # => false (4xx)
response.server_error?  # => false (5xx)

# 回應內容
response.body           # => Raw Body (String)
response.parsed_response# => 自動解析後的 JSON Hash / Array
response['key']         # => 直接透過 [] 存取 parsed_response

# Headers & Cookies
response.headers['content-type'] # => 不區分大小寫
response.cookies['session_id']   # => 解析 Set-Cookie
response.history                 # => 包含轉址過程的所有 HTTP Headers

# 底層 Open3 資訊
response.exit_code      # => Process exit status (0 為正常)
response.stderr         # => curl 執行過程的 stderr 輸出
response.command        # => 實際執行的完整 CLI 陣列
```
