# frozen_string_literal: true

module HttpMimic
  class Client
    attr_accessor :default_options, :config

    def initialize(options = {}, config = nil)
      @default_options = options.dup
      @config = config || HttpMimic.configuration.dup
    end

    def get(url, options = {})
      request(:get, url, options)
    end

    def post(url, options = {})
      request(:post, url, options)
    end

    def put(url, options = {})
      request(:put, url, options)
    end

    def patch(url, options = {})
      request(:patch, url, options)
    end

    def delete(url, options = {})
      request(:delete, url, options)
    end

    def head(url, options = {})
      request(:head, url, options)
    end

    def options(url, options = {})
      request(:options, url, options)
    end

    def request(method, url, options = {})
      merged_options = merge_options(@default_options, options)
      Request.new(method, url, merged_options, @config).perform
    end

    private

    def merge_options(base, override)
      result = base.merge(override)

      # 深度合併 headers
      if base[:headers] || override[:headers]
        base_headers = base[:headers] || {}
        over_headers = override[:headers] || {}
        result[:headers] = base_headers.merge(over_headers)
      end

      # 深度合併 query / params
      base_query = base[:query] || base[:params] || {}
      over_query = override[:query] || override[:params] || {}
      if !base_query.empty? || !over_query.empty?
        result[:query] = base_query.merge(over_query)
      end

      # 深度合併 cookies
      if base[:cookies].is_a?(Hash) && override[:cookies].is_a?(Hash)
        result[:cookies] = base[:cookies].merge(override[:cookies])
      end

      result
    end
  end
end
