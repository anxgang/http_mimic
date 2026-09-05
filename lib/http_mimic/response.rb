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

    def challenge_page?
      if defined?(HttpMimic::Waf::Detector)
        @challenge_page ||= HttpMimic::Waf::Detector.challenge_page?(self)
      else
        false
      end
    end
    alias challenge? challenge_page?
    alias blocked? challenge_page?

    def challenge_type
      if defined?(HttpMimic::Waf::Detector)
        @challenge_type ||= HttpMimic::Waf::Detector.detect(self)
      else
        nil
      end
    end

    def success?
      exit_code == 0 && (code >= 200 && code < 300) && !challenge_page?
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
      exit_code != 0 || client_error? || server_error? || challenge_page?
    end

    def binary?
      content_type = headers['content-type'].to_s.downcase
      ResponseParser::BINARY_MIME_KEYWORDS.any? { |kw| content_type.include?(kw) } ||
        body.to_s.b[0, 1024]&.include?("\x00".b)
    end

    def save_to_file(filepath)
      require 'fileutils'
      FileUtils.mkdir_p(File.dirname(filepath))
      File.binwrite(filepath, body)
      filepath
    end
    alias save save_to_file

    def title
      return nil if binary?
      body[/<title[^>]*>(.*?)<\/title>/im, 1]&.strip
    end

    def og_image
      return nil if binary?
      body[/<meta\s+[^>]*property=["']og:image["'][^>]*content=["']([^"']+)["']/im, 1] ||
        body[/<meta\s+[^>]*content=["']([^"']+)["'][^>]*property=["']og:image["']/im, 1]
    end

    def meta_description
      return nil if binary?
      body[/<meta\s+[^>]*name=["']description["'][^>]*content=["']([^"']+)["']/im, 1] ||
        body[/<meta\s+[^>]*content=["']([^"']+)["'][^>]*name=["']description["']/im, 1]
    end

    def extract_images(base_url: nil)
      return [] if binary?

      base = base_url || request_url || ''
      images = []

      # 1. Match img tags (src, data-src, data-zoom-image, data-original, srcset)
      body.scan(/<img\s+[^>]*>/i).each do |img_tag|
        %w[src data-src data-zoom-image data-original data-high-res-src data-full-size-image-url].each do |attr|
          if match = img_tag.match(/#{attr}=["']([^"']+)["']/i)
            images << match[1].strip
          end
        end

        if match = img_tag.match(/srcset=["']([^"']+)["']/i)
          match[1].split(',').each do |item|
            url = item.strip.split(/\s+/).first
            images << url if url && !url.empty?
          end
        end
      end

      # 2. Match og:image meta tag
      if og = og_image
        images << og
      end

      # 3. Match raw image URLs found in document / script payloads
      body.scan(/https?:[^\s"'<>]+\.(?:jpg|jpeg|png|webp|avif|gif)/i).each do |raw_url|
        images << raw_url
      end

      # Clean, resolve relative URLs to absolute, and deduplicate
      images.map do |img|
        clean_url = img.gsub(/&amp;/, '&').strip
        resolve_url(clean_url, base)
      end.compact.reject(&:empty?).uniq
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
      challenge_info = challenge_page? ? " @challenge=true (#{challenge_type || 'WAF'})" : ""
      "#<#{self.class.name}:0x#{object_id.to_s(16)} @code=#{code}#{challenge_info} @status_message=#{status_message.inspect} @headers=#{headers.to_h.inspect} @parsed_response=#{parsed_response.inspect}>"
    end

    private

    def resolve_url(url, base)
      return nil if url.nil? || url.empty? || url.start_with?('data:', 'javascript:', 'blob:', '#')
      return url if url =~ /\Ahttps?:\/\//i
      return "https:#{url}" if url.start_with?('//')

      return url if base.nil? || base.empty?
      require 'uri'
      URI.join(base, url).to_s
    rescue URI::InvalidURIError
      url
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
