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

      # Automatic Free Proxy Pool integration
      should_auto_proxy = options.fetch(:auto_proxy, config.auto_proxy)
      if should_auto_proxy && !options[:proxy]
        selected_proxy = ProxyPool.get
        if selected_proxy
          options[:proxy] = selected_proxy
          log_debug("[HttpMimic::ProxyPool] Assigned proxy from pool: #{selected_proxy}")
        end
      end

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
      profiles_to_try = determine_profiles(mode, auto_fallback, options[:profile])
      waf_solve_attempts = 0
      best_response = nil
      proxy_retries_left = should_auto_proxy ? (options[:proxy_retries] || config.proxy_retries || 3) : 0

      response = nil
      final_status = nil
      final_stderr = nil
      final_command = nil

      profiles_to_try.each_with_index do |profile, index|
        # Never fall back to plain curl if a WAF challenge has already been detected/attempted
        if profile == :curl && waf_solve_attempts > 0
          log_debug("[HttpMimic] Skipping plain :curl fallback for protected WAF target.")
          next
        end

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

        # Handle proxy failure retry when auto_proxy is enabled
        is_proxy_failure = should_auto_proxy && current_opts[:proxy] && proxy_failure?(status, stderr, response)
        if is_proxy_failure
          ProxyPool.mark_dead(current_opts[:proxy])
          if proxy_retries_left > 0
            proxy_retries_left -= 1
            new_proxy = ProxyPool.get
            log_debug("[HttpMimic::ProxyPool] Proxy #{current_opts[:proxy]} failed (exit #{status&.exitstatus}, code #{response&.code}, empty body: #{response&.body.to_s.empty?}). Retrying with new proxy #{new_proxy} (#{proxy_retries_left} retries left)...")
            options[:proxy] = new_proxy
            redo
          else
            log_debug("[HttpMimic::ProxyPool] Proxy retries exhausted (#{current_opts[:proxy]} failed). Aborting profile fallback.")
            break
          end
        end

        if should_auto_proxy && current_opts[:proxy] && response.success? && !is_proxy_failure
          ProxyPool.mark_alive(current_opts[:proxy])
        end

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

        # Track best response so a 200 isn't wiped out by a failed fallback.
        # Only accept responses from successful curl executions that are not proxy failures or WAF challenges.
        if response && (status.nil? || status.exitstatus == 0) && !is_proxy_failure
          is_challenge = Waf::Detector.challenge_page?(response)
          if !is_challenge
            if best_response.nil?
              best_response = response
            elsif response.success? && !best_response.success?
              best_response = response
            elsif response.code == 200 && best_response.code != 200
              best_response = response
            end
          end
        end

        # Forward any received cookies to subsequent attempts
        if response.cookies && !response.cookies.empty?
          existing_cookies = options[:cookies] ? (options[:cookies].is_a?(Hash) ? options[:cookies] : options[:cookies].to_h) : {}
          options[:cookies] = response.cookies.to_h.merge(existing_cookies)
        end

        auto_solve_waf = options.fetch(:solve_waf, config.auto_solve_waf)
        is_blocked = (status.exitstatus != 0) || is_proxy_failure || retry_statuses.include?(response.code) || Waf::Detector.challenge_page?(response)

        # Only attempt WAF resolution if origin server returned challenge (not a proxy error)
        if is_blocked && !is_proxy_failure && auto_solve_waf && waf_solve_attempts < 2 && method.to_s.upcase == 'GET'
          waf_type = Waf::Detector.detect(response)
          if waf_type
            waf_solve_attempts += 1
            log_debug("[HttpMimic] Detected #{waf_type.to_s.capitalize} WAF challenge. Attempting to solve with QuickJS...")
            solved_resp = Waf.solve(url, response, current_opts)
            if solved_resp
              response = solved_resp
              is_blocked = (response.code != 0 && retry_statuses.include?(response.code)) || Waf::Detector.challenge_page?(response)
              if response.cookies && !response.cookies.empty?
                options[:cookies] = (options[:cookies] || {}).merge(response.cookies.to_h)
              end
              is_challenge_res = Waf::Detector.challenge_page?(response)
              if !is_challenge_res && (response.success? || (response.code == 200 && best_response&.code != 200))
                best_response = response
              end
            end
          end
        end

        if !is_blocked || (index == profiles_to_try.size - 1)
          break
        end

        log_debug("[HttpMimic] Attempt #{index + 1} with #{profile} resulted in status #{response.code}. Triggering smart fallback to next profile...")
      end

      # Preserve best response if the last attempt resulted in a regression (e.g. 403 / error after getting 200)
      if best_response && !Waf::Detector.challenge_page?(best_response) && (response.nil? || response.error? || (final_status && final_status.exitstatus != 0) || Waf::Detector.challenge_page?(response))
        if best_response.success? || (best_response.code == 200 && response&.code != 200)
          response = best_response
        end
      end

      # Automatic SPA Detection & Obscura rendering fallback (strictly requires auto_render_spa: true)
      auto_render_spa = options.fetch(:auto_render_spa, config.auto_render_spa)
      should_render_spa = auto_render_spa && response && response.success? && SpaDetector.spa?(response)
      should_render_cpt = auto_render_spa && response && Waf::Detector.challenge_page?(response)

      if (should_render_spa || should_render_cpt) && method.to_s.upcase == 'GET'
        target_reason = should_render_cpt ? 'WAF challenge page' : 'unhydrated SPA shell'
        log_debug("[HttpMimic] Detected #{target_reason} on #{url}. Automatically rendering with Obscura...")
        begin
          spa_opts = options.dup
          # Forward all validated cookies from Tier 1 (Mode 2: Two-Phase Pipeline)
          if response.cookies && !response.cookies.empty?
            tier1_cookies = response.cookies.to_h
            existing_cookies = spa_opts[:cookies].is_a?(Hash) ? spa_opts[:cookies] : {}
            spa_opts[:cookies] = existing_cookies.merge(tier1_cookies)
          end
          spa_opts[:wait_until] ||= 'load' if should_render_cpt
          rendered_resp = Obscura.render(url, spa_opts)
          if rendered_resp && rendered_resp.success?
            response = rendered_resp
          end
        rescue StandardError => e
          log_debug("[HttpMimic] Automatic Obscura render failed (#{e.message}), keeping Tier 1 response.")
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

      # If the final response was an intercepted dummy 200 from a broken/intercepting proxy, override code
      if response && should_auto_proxy && proxy_failure?(final_status, final_stderr, response)
        if response.code == 200 && response.body.to_s.empty?
          response.instance_variable_set(:@code, 0)
          response.instance_variable_set(:@status_message, 'Proxy Interception Failure (Empty Body)')
        end
      end

      # If the final response is an un-bypassed WAF challenge page, annotate status message so it's clear
      if response && response.challenge_page? && (response.status_message.to_s.empty? || response.status_message == 'OK')
        type_str = response.challenge_type ? response.challenge_type.to_s.capitalize : 'WAF'
        response.instance_variable_set(:@status_message, "Challenge Required (#{type_str})")
      end

      handle_errors(final_status, final_stderr, final_command, response)
      response
    end

    private

    def determine_profiles(mode, auto_fallback, explicit_profile = nil)
      if explicit_profile
        p_sym = explicit_profile.to_sym
        return [p_sym] unless auto_fallback
        defaults = [:impersonate, :android, :ios, :firefox, :safari, :curl]
        return ([p_sym] + defaults).uniq
      end

      case mode
      when :curl, :curl_first
        auto_fallback ? [:curl, :impersonate, :android, :ios, :firefox] : [:curl]
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
      when :firefox_only
        [:firefox]
      when :safari_only
        [:safari]
      when :mobile_first
        auto_fallback ? [:android, :ios, :impersonate, :firefox] : [:mobile]
      when :android_first
        auto_fallback ? [:android, :ios, :impersonate, :firefox] : [:android]
      when :ios_first
        auto_fallback ? [:ios, :android, :impersonate, :firefox] : [:ios]
      when :impersonate_first
        auto_fallback ? [:impersonate, :android, :ios, :firefox] : [:impersonate]
      when :auto, :smart
        auto_fallback ? [:impersonate, :android, :ios, :firefox] : [:impersonate]
      else
        auto_fallback ? [:impersonate, :android, :ios, :firefox] : [:impersonate]
      end
    end

    def proxy_failure?(status, stderr, response)
      # 1. Non-zero exit status from curl when using proxy (connection failed, SSL error, empty reply, etc.)
      return true if status.nil? || status.exitstatus != 0

      # 2. Origin server did not return a valid response (e.g. only CONNECT tunnel block or code 0)
      return true if response.nil? || response.code == 0

      # 3. Known proxy-level error codes
      return true if [407, 502, 503, 504].include?(response.code)

      # 4. Proxy fake 200 OK interception detection:
      # A GET request that returns 200 with empty body is almost always a proxy interception / dummy response
      if method.to_s.upcase == 'GET' && response.code == 200 && response.body.to_s.empty?
        server_hdr  = response.headers['server'].to_s.downcase
        via_hdr     = response.headers['via'].to_s.downcase
        content_len = response.headers['content-length']

        is_proxy_marker = server_hdr.include?('proxy') ||
                          server_hdr.include?('squid') ||
                          server_hdr.include?('console') ||
                          server_hdr.include?('privoxy') ||
                          server_hdr.include?('tinyproxy') ||
                          via_hdr.include?('proxy') ||
                          content_len == '0'

        return true if is_proxy_marker
      end

      false
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
