# frozen_string_literal: true

require 'open3'

module HttpMimic
  class Request
    attr_reader :method, :url, :options, :config

    def initialize(method, url, options = {}, config = nil)
      @method  = method
      @url     = url
      @options = options.dup
      @config  = config || HttpMimic.configuration
    end

    def perform
      mode = (options[:mode] || config.mode || :auto).to_sym

      # Delegate directly to Obscura headless SPA renderer if requested
      if options[:render] == :spa || options[:render] == :obscura || mode == :spa || mode == :obscura
        return Obscura.render(url, options)
      end

      auto_fallback = options.fetch(:auto_fallback, config.auto_fallback)
      retry_statuses = options[:retry_statuses] || config.retry_statuses || [403, 429, 503]

      # Persistent CookieStore integration
      should_persist_cookie = options.fetch(:persist_cookies, config.persist_cookies)
      host = CookieStore.extract_host(url)

      if should_persist_cookie && host
        stored_cookies = CookieStore.load(host)
        if stored_cookies && !stored_cookies.empty?
          log_debug("[HttpMimic::CookieStore] Loaded #{stored_cookies.size} persistent cookies for #{host}")
          user_cookies = options[:cookies] ? (options[:cookies].is_a?(Hash) ? options[:cookies] : options[:cookies].to_h) : {}
          options[:cookies] = stored_cookies.merge(user_cookies)
        end
      end

      attempts = []
      profiles_to_try = determine_profiles(mode, auto_fallback)
      waf_solve_attempted = false

      response = nil
      final_status = nil
      final_stderr = nil
      final_command = nil

      profiles_to_try.each_with_index do |profile, index|
        current_opts = options.merge(profile: profile)

        builder = CommandBuilder.new(method, url, current_opts, config)
        binary, args, stdin_data, final_url = builder.build
        full_command = [binary] + args

        log_debug("Executing HttpMimic command (attempt #{index + 1}, profile: #{profile}): #{full_command.join(' ')}")
        log_debug("Stdin data: #{stdin_data}") if stdin_data

        stdout, stderr, status = execute_open3(full_command, stdin_data)

        log_debug("Curl exit status: #{status.exitstatus}")
        log_debug("Curl stderr: #{stderr}") unless stderr.empty?

        response = ResponseParser.new(
          stdout,
          exit_status: status,
          stderr: stderr,
          command: full_command,
          request_url: final_url
        ).parse

        response.mode_used = profile
        response.fallback_triggered = (index > 0)

        attempts << {
          attempt: index + 1,
          profile: profile,
          command: full_command,
          code: response.code,
          exit_code: status.exitstatus,
          success: response.success?
        }
        response.attempts = attempts

        final_status = status
        final_stderr = stderr
        final_command = full_command

        # Forward any received cookies to subsequent attempts
        if response.cookies && !response.cookies.empty?
          existing_cookies = options[:cookies] ? (options[:cookies].is_a?(Hash) ? options[:cookies] : options[:cookies].to_h) : {}
          options[:cookies] = response.cookies.to_h.merge(existing_cookies)
        end

        auto_solve_waf = options.fetch(:solve_waf, config.auto_solve_waf)
        is_blocked = (status.exitstatus != 0) || retry_statuses.include?(response.code) || Waf::Detector.challenge_page?(response)

        # Only attempt WAF resolution once per request to avoid unnecessary latency on subsequent fallbacks
        if is_blocked && auto_solve_waf && !waf_solve_attempted && method.to_s.upcase == 'GET'
          waf_type = Waf::Detector.detect(response)
          if waf_type
            waf_solve_attempted = true
            log_debug("[HttpMimic] Detected #{waf_type.to_s.capitalize} WAF challenge. Attempting to solve with QuickJS...")
            solved_resp = Waf.solve(url, response, current_opts)
            if solved_resp
              response = solved_resp
              is_blocked = (response.code != 0 && retry_statuses.include?(response.code)) || Waf::Detector.challenge_page?(response)
              if response.cookies && !response.cookies.empty?
                options[:cookies] = (options[:cookies] || {}).merge(response.cookies.to_h)
              end
            end
          end
        end

        if !is_blocked || (index == profiles_to_try.size - 1)
          break
        end

        log_debug("[HttpMimic] Attempt #{index + 1} with #{profile} resulted in status #{response.code}. Triggering smart fallback to next profile...")
      end

      # Automatic SPA Detection & Obscura rendering fallback
      auto_render_spa = options.fetch(:auto_render_spa, config.auto_render_spa)
      if auto_render_spa && response && response.success? && method.to_s.upcase == 'GET'
        if SpaDetector.spa?(response)
          log_debug("[HttpMimic] Detected unhydrated SPA shell on #{url}. Automatically rendering with Obscura...")
          begin
            spa_opts = options.dup
            # Forward all validated cookies from Tier 1 (Mode 2: Two-Phase Pipeline)
            if response.cookies && !response.cookies.empty?
              tier1_cookies = response.cookies.to_h
              existing_cookies = spa_opts[:cookies].is_a?(Hash) ? spa_opts[:cookies] : {}
              spa_opts[:cookies] = existing_cookies.merge(tier1_cookies)
            end
            rendered_resp = Obscura.render(url, spa_opts)
            if rendered_resp && rendered_resp.success?
              response = rendered_resp
            end
          rescue StandardError => e
            log_debug("[HttpMimic] Automatic Obscura SPA render failed (#{e.message}), keeping Tier 1 response.")
          end
        end
      end

      # Persist cookies back to store if enabled
      if should_persist_cookie && host
        is_success = response && (response.success? || response.redirect?) && !Waf::Detector.challenge_page?(response) && (final_status.nil? || final_status.exitstatus == 0)
        verification_failed = !is_success && response && (
          [401, 403].include?(response.code) ||
          retry_statuses.include?(response.code) ||
          Waf::Detector.challenge_page?(response)
        )

        persist_on_failure = options.fetch(:persist_on_failure, config.persist_on_failure)
        clear_on_failure = options.fetch(:clear_on_failure, config.clear_on_failure)

        if is_success || persist_on_failure
          if response && response.cookies && !response.cookies.empty?
            CookieStore.save(host, response.cookies)
            log_debug("[HttpMimic::CookieStore] Saved #{response.cookies.size} cookies for #{host}")
          end
        elsif clear_on_failure && verification_failed
          CookieStore.clear(host)
          log_debug("[HttpMimic::CookieStore] Verification failed for #{host} (status: #{response&.code}). Cleared stored cookies.")
        end
      end

      handle_errors(final_status, final_stderr, final_command, response)
      response
    end

    private

    def determine_profiles(mode, auto_fallback)
      case mode
      when :curl, :curl_first
        auto_fallback ? [:curl, :impersonate, :android, :ios] : [:curl]
      when :curl_only
        [:curl]
      when :impersonate_only
        [:impersonate]
      when :mobile_only
        [:mobile]
      when :android_only
        [:android]
      when :ios_only
        [:ios]
      when :mobile_first
        auto_fallback ? [:android, :ios, :impersonate, :curl] : [:mobile]
      when :android_first
        auto_fallback ? [:android, :ios, :impersonate, :curl] : [:android]
      when :ios_first
        auto_fallback ? [:ios, :android, :impersonate, :curl] : [:ios]
      when :impersonate_first
        auto_fallback ? [:impersonate, :android, :ios, :curl] : [:impersonate]
      when :auto, :smart
        auto_fallback ? [:impersonate, :android, :ios, :curl] : [:impersonate]
      else
        auto_fallback ? [:impersonate, :android, :ios, :curl] : [:impersonate]
      end
    end

    def execute_open3(command_array, stdin_data)
      if stdin_data
        Open3.capture3(*command_array, stdin_data: stdin_data)
      else
        Open3.capture3(*command_array)
      end
    rescue Errno::ENOENT => e
      raise BinaryNotFoundError, "Executable not found #{command_array.first}: #{e.message}"
    end

    def handle_errors(status, stderr, command, response)
      raise_error = options.fetch(:raise_on_error, config.raise_on_error)
      return unless status
      exit_code = status.exitstatus

      if exit_code != 0
        message = "curl execution error (exit code #{exit_code}): #{stderr.strip}"
        error_class = case exit_code
                      when 28
                        TimeoutError
                      when 6, 7, 52
                        ConnectionError
                      when 35, 51, 60
                        SSLError
                      else
                        CommandError
                      end

        if raise_error
          raise error_class.new(message, exit_code: exit_code, stderr: stderr, command: command, response: response)
        end
      elsif raise_error && response&.error?
        raise CommandError.new("HTTP request failed (status #{response.code})", exit_code: exit_code, stderr: stderr, command: command, response: response)
      end
    end

    def log_debug(message)
      if config.logger
        config.logger.debug(message)
      elsif config.debug || options[:debug]
        puts "[HttpMimic DEBUG] #{message}"
      end
    end
  end
end
