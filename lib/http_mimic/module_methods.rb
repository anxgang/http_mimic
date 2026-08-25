# frozen_string_literal: true

module HttpMimic
  module ModuleMethods
    def base_uri(uri = nil)
      return default_options[:base_uri] if uri.nil?
      default_options[:base_uri] = uri
    end

    def headers(h = nil)
      return default_options[:headers] if h.nil?
      default_options[:headers] ||= {}
      default_options[:headers].merge!(h)
    end

    def default_params(params = nil)
      return default_options[:query] if params.nil?
      default_options[:query] ||= {}
      default_options[:query].merge!(params)
    end
    alias default_query default_params

    def default_timeout(seconds = nil)
      return default_options[:timeout] if seconds.nil?
      default_options[:timeout] = seconds
    end

    def impersonate(target = nil)
      return default_options[:impersonate] if target.nil?
      default_options[:impersonate] = target
    end

    def proxy(proxy_str = nil)
      return default_options[:proxy] if proxy_str.nil?
      default_options[:proxy] = proxy_str
    end

    def cookies(c = nil)
      return default_options[:cookies] if c.nil?
      default_options[:cookies] ||= {}
      default_options[:cookies].merge!(c)
    end

    def mode(m = nil)
      return default_options[:mode] if m.nil?
      default_options[:mode] = m
    end

    def auto_fallback(enabled = nil)
      return default_options[:auto_fallback] if enabled.nil?
      default_options[:auto_fallback] = enabled
    end

    def retry_statuses(statuses = nil)
      return default_options[:retry_statuses] if statuses.nil?
      default_options[:retry_statuses] = statuses
    end

    def default_options
      @default_options ||= {}
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
      merged = default_options.merge(options)

      # Deep merge headers
      if default_options[:headers] || options[:headers]
        base_h = default_options[:headers] || {}
        opt_h = options[:headers] || {}
        merged[:headers] = base_h.merge(opt_h)
      end

      # Deep merge query
      base_q = default_options[:query] || {}
      opt_q = options[:query] || options[:params] || {}
      if !base_q.empty? || !opt_q.empty?
        merged[:query] = base_q.merge(opt_q)
      end

      # Deep merge cookies
      if default_options[:cookies].is_a?(Hash) && options[:cookies].is_a?(Hash)
        merged[:cookies] = default_options[:cookies].merge(options[:cookies])
      end

      Request.new(method, url, merged).perform
    end
  end
end
