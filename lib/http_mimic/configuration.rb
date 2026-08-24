# frozen_string_literal: true

module HttpMimic
  class Configuration
    attr_accessor :default_impersonate
    attr_accessor :binary_path
    attr_accessor :fallback_to_curl
    attr_accessor :default_timeout
    attr_accessor :default_connect_timeout
    attr_accessor :follow_redirects
    attr_accessor :max_redirects
    attr_accessor :raise_on_error
    attr_accessor :logger
    attr_accessor :debug

    # Webdrivers-like 自動下載與管理設定
    attr_accessor :auto_download
    attr_accessor :driver_version
    attr_accessor :install_dir
    attr_accessor :github_repo

    def initialize
      @default_impersonate      = 'chrome116'
      @binary_path              = nil
      @fallback_to_curl         = true
      @default_timeout          = 30
      @default_connect_timeout  = 10
      @follow_redirects         = true
      @max_redirects            = 10
      @raise_on_error           = false
      @logger                   = nil
      @debug                    = false

      # 預設開啟自動下載 curl-impersonate driver (lexiforest)
      @auto_download            = true
      @driver_version           = 'v2.1.1'
      @install_dir              = File.expand_path('~/.http_mimic/bin')
      @github_repo              = 'lexiforest/curl-impersonate'
    end
  end
end
