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
    end
  end
end
