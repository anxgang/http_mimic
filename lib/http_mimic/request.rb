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
      auto_fallback = options.fetch(:auto_fallback, config.auto_fallback)
      retry_statuses = options[:retry_statuses] || config.retry_statuses || [403, 429, 503]

      attempts = []
      profiles_to_try = determine_profiles(mode, auto_fallback)

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

        is_blocked = (status.exitstatus != 0) || retry_statuses.include?(response.code)
        if !is_blocked || (index == profiles_to_try.size - 1)
          break
        end

        log_debug("[HttpMimic] Attempt #{index + 1} with #{profile} resulted in status #{response.code}. Triggering smart fallback to next profile...")
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
