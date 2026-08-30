# frozen_string_literal: true

require 'open3'
require 'uri'
require 'json'

module HttpMimic
  module Obscura
    class ExecutionError < HttpMimic::Error; end
    class BinaryNotFoundError < HttpMimic::Error; end

    class << self
      # Renders a web page using the Obscura headless SPA engine and returns an HttpMimic::Response
      #
      # @param url [String, URI] The target URL to render
      # @param options [Hash] Rendering options
      # @option options [String] :wait_until ('networkidle0') Wait condition (e.g. 'load', 'domcontentloaded', 'networkidle0')
      # @option options [Integer] :timeout Per-command timeout in seconds
      # @option options [String] :proxy Proxy URL (e.g. 'socks5://127.0.0.1:1080' or 'http://...')
      # @option options [String] :eval JavaScript expression to evaluate on the page
      # @option options [String] :dump Output format ('html', 'text', 'links')
      # @return [HttpMimic::Response]
      def render(url, options = {})
        bin = resolve_binary
        raise BinaryNotFoundError, "Obscura binary not found. Run HttpMimic.download_obscura! or configure obscura_path." unless bin

        args = [bin, 'fetch', url.to_s]

        # Dump format: default to html (can be 'html', 'text', 'links', 'markdown', 'original', 'cookies')
        dump_format = options[:dump] || 'html'
        args << '--dump' << dump_format.to_s

        # Stealth mode (enabled by default)
        args << '--stealth' if options.fetch(:stealth, true)

        # Wait condition
        if options[:wait_until]
          args << '--wait-until' << options[:wait_until].to_s
        end

        # Wait delay
        if options[:wait]
          args << '--wait' << options[:wait].to_i.to_s
        end

        # Timeout in seconds (integer)
        timeout = options[:timeout] || HttpMimic.configuration.default_timeout
        args << '--timeout' << timeout.to_i.to_s if timeout

        # User Agent
        if options[:user_agent]
          args << '--user-agent' << options[:user_agent].to_s
        end

        # Proxy
        if options[:proxy]
          args << '--proxy' << options[:proxy].to_s
        end

        # Cookies: pass cookies string or hash (Two-Phase Pipeline support)
        if options[:cookies] || options[:cookie]
          cookie_val = options[:cookies] || options[:cookie]
          cookie_str = if cookie_val.is_a?(Hash)
            cookie_val.map { |k, v| "#{k}=#{v}" }.join('; ')
          elsif cookie_val.is_a?(Array)
            cookie_val.join('; ')
          else
            cookie_val.to_s
          end
          args << '--cookie' << cookie_str unless cookie_str.empty?
        end

        # Optional JS evaluation
        args << '--eval' << options[:eval].to_s if options[:eval]

        # Selector
        args << '--selector' << options[:selector].to_s if options[:selector]

        log_debug("Executing Obscura SPA render: #{args.join(' ')}")

        stdout, stderr, status = Open3.capture3(*args)

        code = (status && status.success?) ? 200 : (status ? status.exitstatus : 500)

        raw_headers = "HTTP/2 200 OK\r\ncontent-type: text/html; charset=utf-8\r\nx-rendered-by: obscura\r\n\r\n"
        headers = Headers.new({ 'content-type' => 'text/html; charset=utf-8', 'x-rendered-by' => 'obscura' })

        Response.new(
          code: code,
          http_version: 'HTTP/2',
          status_message: status&.success? ? 'OK (Obscura SPA Rendered)' : 'Error',
          headers: headers,
          cookies: Cookies.new,
          body: stdout,
          parsed_response: nil,
          raw_headers: raw_headers,
          history: [],
          request_url: url.to_s,
          stderr: stderr,
          exit_code: status ? status.exitstatus : 0,
          command: args.join(' ')
        )
      end

      def resolve_binary
        # 1. Configured custom path
        custom_path = HttpMimic.configuration.obscura_path
        if custom_path && (File.file?(custom_path) || File.executable?(custom_path))
          return custom_path
        end

        # 2. Check install directory or system PATH
        installed_path = Downloader.obscura_path
        return installed_path if installed_path

        # 3. Auto-download if enabled
        if HttpMimic.configuration.auto_download
          begin
            return Downloader.download_obscura!
          rescue StandardError => e
            HttpMimic.configuration.logger&.warn("[HttpMimic::Obscura] Auto-download failed: #{e.message}")
          end
        end

        nil
      end

      private

      def log_debug(msg)
        if HttpMimic.configuration.logger
          HttpMimic.configuration.logger.debug("[HttpMimic::Obscura] #{msg}")
        elsif HttpMimic.configuration.debug
          puts "[HttpMimic::Obscura] #{msg}"
        end
      end
    end
  end
end
