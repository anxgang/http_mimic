# frozen_string_literal: true

module HttpMimic
  class Response
    attr_reader :code,
                :http_version,
                :status_message,
                :headers,
                :cookies,
                :body,
                :parsed_response,
                :raw_headers,
                :history,
                :request_url,
                :stderr,
                :exit_code,
                :command

    attr_accessor :mode_used,
                  :fallback_triggered,
                  :attempts

    alias status code
    alias strategy_used mode_used

    def initialize(attributes = {})
      @code               = attributes[:code] || 0
      @http_version       = attributes[:http_version]
      @status_message     = attributes[:status_message]
      @headers            = attributes[:headers] || Headers.new
      @cookies            = attributes[:cookies] || Cookies.new
      @body               = attributes[:body] || ''
      @parsed_response    = attributes[:parsed_response]
      @raw_headers        = attributes[:raw_headers] || ''
      @history            = attributes[:history] || []
      @request_url        = attributes[:request_url]
      @stderr             = attributes[:stderr] || ''
      @exit_code          = attributes[:exit_code] || 0
      @command            = attributes[:command]
      @mode_used          = attributes[:mode_used] || :impersonate
      @fallback_triggered = attributes[:fallback_triggered] || false
      @attempts           = attributes[:attempts] || []
    end

    def fallback_triggered?
      !!@fallback_triggered
    end

    def success?
      code >= 200 && code < 300
    end
    alias ok? success?

    def redirect?
      code >= 300 && code < 400
    end

    def client_error?
      code >= 400 && code < 500
    end

    def server_error?
      code >= 500 && code < 600
    end

    def error?
      client_error? || server_error?
    end

    def [](key)
      if parsed_response.is_a?(Hash) || parsed_response.is_a?(Array)
        parsed_response[key]
      else
        nil
      end
    end

    def to_s
      body.to_s
    end
    alias to_str to_s

    def blank?
      body.nil? || body.strip.empty?
    end

    def present?
      !blank?
    end

    def inspect
      "#<#{self.class.name}:0x#{object_id.to_s(16)} @code=#{code} @status_message=#{status_message.inspect} @headers=#{headers.to_h.inspect} @parsed_response=#{parsed_response.inspect}>"
    end

    def method_missing(method_name, *args, &block)
      if parsed_response.respond_to?(method_name)
        parsed_response.public_send(method_name, *args, &block)
      elsif body.respond_to?(method_name)
        body.public_send(method_name, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      parsed_response.respond_to?(method_name, include_private) ||
        body.respond_to?(method_name, include_private) ||
        super
    end
  end
end
