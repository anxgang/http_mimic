# frozen_string_literal: true

require 'json'

module HttpMimic
  class ResponseParser
    HTTP_STATUS_LINE_REGEX = /\AHTTP\/(?<version>[\d\.]+)\s+(?<code>\d{3})(?:\s+(?<message>.*))?/i
    HTTP_STATUS_LINE_B     = /\AHTTP\/(?:[\d\.]+)\s+\d{3}/i
    PROXY_CONNECT_REGEX    = /\AHTTP\/[\d\.]+\s+200\s+Connection\s+established/i
    BINARY_MIME_KEYWORDS   = %w[image/ audio/ video/ pdf octet-stream zip gzip tar compressed stream font wasm].freeze

    attr_reader :raw_output, :exit_status, :stderr, :command, :request_url

    def initialize(raw_output, exit_status: nil, stderr: nil, command: nil, request_url: nil)
      @raw_output   = raw_output.to_s
      @exit_status  = exit_status
      @stderr       = stderr.to_s
      @command      = command
      @request_url  = request_url
    end

    def parse
      # Split header blocks and body in binary-safe manner
      header_blocks, raw_body = split_headers_and_body(@raw_output)

      # Strip proxy CONNECT tunnel handshake blocks (e.g. "HTTP/1.1 200 Connection established")
      while header_blocks.first && header_blocks.first =~ PROXY_CONNECT_REGEX
        header_blocks.shift
      end

      final_header_block = header_blocks.last || ''
      history_header_blocks = header_blocks.size > 1 ? header_blocks[0...-1] : []

      # Parse final status line and headers
      code, http_version, status_message, headers, cookies = parse_header_block(final_header_block)

      # Parse redirect history
      history = history_header_blocks.map do |block|
        h_code, h_version, h_msg, h_headers, h_cookies = parse_header_block(block)
        {
          code: h_code,
          http_version: h_version,
          status_message: h_msg,
          headers: h_headers,
          cookies: h_cookies,
          raw_headers: block
        }
      end

      # Process body: retain raw bytes for binary, or UTF-8 encode for text
      content_type = headers['content-type'].to_s.downcase
      body = if binary_content?(content_type, raw_body)
               raw_body
             else
               raw_body.dup.force_encoding('UTF-8').scrub
             end

      # Parse body (auto-detect JSON)
      parsed_body = parse_body(body, headers)

      Response.new(
        code: code,
        http_version: http_version,
        status_message: status_message,
        headers: headers,
        cookies: cookies,
        body: body,
        parsed_response: parsed_body,
        raw_headers: final_header_block,
        history: history,
        request_url: request_url,
        stderr: stderr,
        exit_code: exit_status ? exit_status.exitstatus : 0,
        command: command
      )
    end

    private

    # Split raw_output into header blocks and body in a binary-safe manner
    def split_headers_and_body(text)
      return [[], ''.b] if text.nil? || text.empty?

      remaining = text.to_s.b
      header_blocks = []

      while remaining =~ HTTP_STATUS_LINE_B
        crlf_idx = remaining.index("\r\n\r\n".b)
        lf_idx   = remaining.index("\n\n".b)

        break unless crlf_idx || lf_idx

        if crlf_idx && lf_idx
          delim_pos = [crlf_idx, lf_idx].min
          delim_len = (delim_pos == crlf_idx) ? 4 : 2
        elsif crlf_idx
          delim_pos = crlf_idx
          delim_len = 4
        else
          delim_pos = lf_idx
          delim_len = 2
        end

        header_block = remaining[0...delim_pos].force_encoding('UTF-8').scrub
        header_blocks << header_block
        remaining = remaining[(delim_pos + delim_len)..-1] || ''.b
      end

      [header_blocks, remaining]
    end

    def parse_header_block(block)
      return [0, nil, nil, Headers.new, Cookies.new] if block.nil? || block.empty?

      lines = block.split(/\r?\n/).map(&:strip).reject(&:empty?)
      status_line = lines.first || ''
      header_lines = lines[1..-1] || []

      code = 0
      http_version = nil
      status_message = nil

      if match = status_line.match(HTTP_STATUS_LINE_REGEX)
        code = match[:code].to_i
        http_version = match[:version]
        status_message = match[:message] ? match[:message].strip : ''
      end

      headers = Headers.new
      set_cookies = []

      header_lines.each do |line|
        key, val = line.split(':', 2)
        next unless key && val

        key = key.strip
        val = val.strip

        if key.downcase == 'set-cookie'
          set_cookies << val
          headers.add(key, val)
        else
          headers[key] = val
        end
      end

      cookies = Cookies.parse_set_cookie(set_cookies)

      [code, http_version, status_message, headers, cookies]
    end

    def binary_content?(content_type, body)
      return true if BINARY_MIME_KEYWORDS.any? { |kw| content_type.include?(kw) }

      # Check for null bytes in the initial portion of body
      sample = body[0, 1024]
      sample&.include?("\x00".b)
    end

    def parse_body(body, headers)
      return nil if body.nil? || body.empty?

      content_type = headers['content-type'].to_s.downcase
      return body if binary_content?(content_type, body)

      trimmed = body.strip
      if content_type.include?('json') || trimmed.start_with?('{', '[')
        begin
          JSON.parse(body)
        rescue JSON::ParserError
          body
        end
      else
        body
      end
    end
  end
end
