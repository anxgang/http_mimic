# HttpMimic

`http_mimic` 是一個基於 `Open3.capture3` 與 `curl-impersonate` 的 Ruby HTTP Client Gem。
它的目標是提供類似 **HTTParty** 那樣優雅、簡潔、直覺的語法，同時具備類似 **Webdrivers** 的自動下載與驅動管理能力，可直接下載並安裝 [`lexiforest/curl-impersonate`](https://github.com/lexiforest/curl-impersonate) 的特定版本執行檔，模擬真實 Chrome / Firefox / Safari / Edge / Tor 的 TLS / HTTP2 指紋（Fingerprint）與握手。

---

## 🌟 特色

- **Webdrivers 風格的自動下載與管理**：
  - 整合 [`lexiforest/curl-impersonate`](https://github.com/lexiforest/curl-impersonate) 作為主要二進制檔案來源。
  - **自動偵測作業系統與 CPU 架構**（支援 macOS ARM/Intel、Linux x86_64/aarch64/musl、Windows 等）。
  - 當本地未安裝時，**全自動下載並解壓縮**至 `~/.http_mimic/bin`，無需手動配置環境。
  - 亦可手動呼叫 `HttpMimic.download_driver!` 預先安裝或更新。
- **真實瀏覽器握手與指紋模擬**：
  - 支援 `chrome116`、`chrome120`、`chrome124`、`chrome131`、`chrome133a`、`chrome136`、`chrome142`、`chrome99-110`。
  - 支援 `firefox133`、`firefox135`、`firefox144`、`firefox117` 等。
  - 支援 `safari180`、`safari170`、`safari155`、`safari153` 等。
  - 支援 `edge101`、`edge99`、`tor145` 等。
- **HTTParty 風格 API**：支援 `HttpMimic.get`、`HttpMimic.post`、類別 Mixin (`include HttpMimic`) 與實例化 `HttpMimic::Client.new`。
- **無 Shell 注入風險**：使用 `Open3.capture3(*cmd_array)` 以陣列參數執行，安全可靠。
- **自動解析 HTTP 回應**：
  - HTTP 狀態碼 (`response.code`、`response.success?`、`response.status_message`)
  - 不區分大小寫的 Header 存取 (`response.headers['Content-Type']`)
  - Set-Cookie 自動解析 (`response.cookies['session_id']`)
  - JSON 自動反序列化與物件委派 (`response['key']`、`response.parsed_response`)
  - Redirect 歷史紀錄追蹤 (`response.history`)
- **完整的請求選項**：支援 `query`、`headers`、`json`、`body` (form data)、`cookies`、`timeout`、`proxy`、`basic_auth`、`bearer_token`、`insecure`、自訂 `curl_options` 等。
- **自動退回機制 (Graceful Fallback)**：若未開啟自動下載且系統尚未安裝特定版本執行檔時，預設自動退回至系統標準 `curl`。

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

## 🤖 Webdrivers 風格的 Driver 管理

`HttpMimic` 預設會在首次發送請求時，自動至 GitHub Releases 下載對應平台架構的 `curl-impersonate` 執行檔並放置於 `~/.http_mimic/bin`。

你也可以透過以下方法手動管理：

```ruby
# 檢查本地是否已安裝 driver
HttpMimic.driver_installed? # => true / false

# 手動觸發下載（預設下載最新穩定版 v2.1.1）
HttpMimic.download_driver!

# 指定版本或強制重新下載
HttpMimic.download_driver!(version: 'v2.1.1', force: true)

# 查看已安裝的所有瀏覽器 binary 名稱
HttpMimic::Downloader.available_binaries
# => ["curl_chrome116", "curl_chrome120", "curl_chrome131", "curl_firefox135", "curl_safari180", ...]
```

---

## 🚀 快速上手

### 1. 直接呼叫模組方法 (Direct Calls)

```ruby
require 'http_mimic'

# 發送 GET 請求（模擬 Chrome 131 指紋）
response = HttpMimic.get(
  'https://tls.browserleaks.com/json',
  impersonate: 'chrome131'
)

puts response.code                    # => 200
puts response.success?                 # => true
puts response['ja3_hash']             # => 真實 Chrome 131 JA3 指紋
puts response.headers['content-type'] # => "application/json"

# 發送 POST JSON 請求
response = HttpMimic.post(
  'https://httpbin.org/post',
  json: { name: 'Alice', role: 'admin' },
  impersonate: 'safari180' # 模擬 Safari 18.0 指紋
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
  impersonate 'chrome120' # 預設模擬 Chrome 120
  default_timeout 30
  headers 'Accept-Language' => 'zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7'

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

### 3. Client 實例化模式 (Instance Mode)

```ruby
client = HttpMimic::Client.new(
  base_uri: 'https://api.example.com',
  impersonate: 'firefox135',
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
  # 瀏覽器模擬與請求選項
  config.default_impersonate     = 'chrome116' # 預設模擬目標
  config.default_timeout         = 30          # 預設 Timeout (秒)
  config.default_connect_timeout = 10          # 預設連線 Timeout (秒)
  config.follow_redirects        = true        # 自動追蹤 3xx 轉址
  config.max_redirects           = 10          # 最大轉址次數
  config.fallback_to_curl        = true        # 找不到 impersonate binary 時退回系統 curl
  config.raise_on_error          = false       # 是否在 HTTP 錯誤或連線失敗時拋出例外
  config.debug                   = false       # 是否輸出除錯日誌

  # Webdrivers-like 自動下載設定 (預設已啟用)
  config.auto_download           = true                                  # 是否在缺少 binary 時自動下載
  config.driver_version          = 'v2.1.1'                              # 下載的 release 版本
  config.install_dir             = File.expand_path('~/.http_mimic/bin') # 執行檔存放目錄
  config.github_repo             = 'lexiforest/curl-impersonate'         # 來源 GitHub 儲存庫
end
```

---

## 🛠️ 支援的 HTTP Verbs 與選項

### 常用 Options
| Option | 類型 | 說明 |
| :--- | :--- | :--- |
| `:impersonate` | String | 模擬目標（如 `'chrome131'`, `'chrome120'`, `'firefox135'`, `'safari180'`, `'tor145'` 等） |
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
