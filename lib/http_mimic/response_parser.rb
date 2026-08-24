# frozen_string_literal: true

require 'json'

module HttpMimic
  class ResponseParser
    HTTP_STATUS_LINE_REGEX = /\AHTTP\/(?<version>[\d\.]+)\s+(?<code>\d{3})(?:\s+(?<message>.*))?/i

    attr_reader :raw_output, :exit_status, :stderr, :command, :request_url

    def initialize(raw_output, exit_status: nil, stderr: nil, command: nil, request_url: nil)
      @raw_output   = raw_output.to_s
      @exit_status  = exit_status
      @stderr       = stderr.to_s
      @command      = command
      @request_url  = request_url
    end

    def parse
      # Split header blocks and body
      header_blocks, body = split_headers_and_body(@raw_output)

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

    # Split raw_output into header blocks and body by \r?\n\r?\n
    def split_headers_and_body(text)
      return [[], ''] if text.nil? || text.empty?

      # Normalize line endings
      normalized = text.gsub(/\r\n/, "\n")
      parts = normalized.split("\n\n")

      header_blocks = []
      body_index = 0

      parts.each_with_index do |part, idx|
        trimmed = part.strip
        if trimmed =~ HTTP_STATUS_LINE_REGEX
          header_blocks << part
          body_index = idx + 1
        else
          # Once a non-HTTP status block is encountered, the rest is body
          break
        end
      end

      # Combine remaining parts as body
      body = parts[body_index..-1] ? parts[body_index..-1].join("\n\n") : ''

      [header_blocks, body]
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

    def parse_body(body, headers)
      return nil if body.nil? || body.empty?

      content_type = headers['content-type'].to_s.downcase

      if content_type.include?('json') || body.strip.start_with?('{', '[')
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
