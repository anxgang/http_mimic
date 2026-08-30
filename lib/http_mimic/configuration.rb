# frozen_string_literal: true

module HttpMimic
  class Configuration
    # Browser simulation & request defaults
    attr_accessor :default_impersonate
    attr_accessor :default_mobile_impersonate
    attr_accessor :binary_path
    attr_accessor :fallback_to_curl
    attr_accessor :default_timeout
    attr_accessor :default_connect_timeout
    attr_accessor :follow_redirects
    attr_accessor :max_redirects
    attr_accessor :raise_on_error
    attr_accessor :logger
    attr_accessor :debug

    # Multi-strategy and smart auto-fallback settings
    attr_accessor :mode
    attr_accessor :auto_fallback
    attr_accessor :retry_statuses

    # Webdrivers-like auto download and driver management settings
    attr_accessor :auto_download
    attr_accessor :driver_version
    attr_accessor :install_dir
    attr_accessor :github_repo

    # QuickJS standalone binary management settings
    attr_accessor :qjs_version
    attr_accessor :qjs_github_repo

    # Obscura headless SPA engine settings
    attr_accessor :obscura_version
    attr_accessor :obscura_github_repo
    attr_accessor :obscura_path
    attr_accessor :auto_render_spa

    # WAF & JS challenge solving settings
    attr_accessor :auto_solve_waf

    # Shared Host-based CookieStore settings
    attr_accessor :persist_cookies
    attr_accessor :cookie_store_dir

    # Modern Navigation Headers simulation
    attr_accessor :navigation_headers

    def initialize
      @default_impersonate         = 'chrome131'
      @default_mobile_impersonate  = 'safari180_ios'
      @binary_path                 = nil
      @fallback_to_curl            = true
      @default_timeout             = 30
      @default_connect_timeout     = 10
      @follow_redirects            = true
      @max_redirects               = 10
      @raise_on_error              = false
      @logger                      = nil
      @debug                       = false

      # Multi-strategy defaults: :auto seamlessly falls back between impersonate, mobile, and curl
      @mode                        = :auto
      @auto_fallback               = true
      @retry_statuses              = [403, 429, 503]

      # Enable automatic downloading of curl-impersonate driver (lexiforest) by default
      @auto_download               = true
      @driver_version              = 'v2.1.1'
      @install_dir                 = File.expand_path('~/.http_mimic/bin')
      @github_repo                 = 'lexiforest/curl-impersonate'

      # QuickJS defaults
      @qjs_version                 = 'v0.16.2'
      @qjs_github_repo             = 'quickjs-ng/quickjs'

      # Obscura defaults (Lightweight Rust+V8 headless SPA engine)
      # Temporarily points to 'anxgang/obscura' (v0.2.2) for Web Worker importScripts support.
      # Will switch back to 'h4ckf0r0day/obscura' once upstream Pull Request is merged.
      # @obscura_github_repo       = 'h4ckf0r0day/obscura'
      @obscura_version             = 'v0.2.2'
      @obscura_github_repo         = 'anxgang/obscura'
      @obscura_path                = nil
      @auto_render_spa             = false

      # WAF challenge solving defaults
      @auto_solve_waf              = true

      # Shared Host CookieStore defaults
      @persist_cookies             = false
      @cookie_store_dir            = File.expand_path('~/.http_mimic/cookies')

      # Navigation Headers defaults
      @navigation_headers          = true
    end
  end
end
