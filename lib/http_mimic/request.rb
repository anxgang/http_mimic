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
      builder = CommandBuilder.new(method, url, options, config)
      binary, args, stdin_data, final_url = builder.build

      full_command = [binary] + args

      log_debug("Executing HttpMimic command: #{full_command.join(' ')}")
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

      handle_errors(status, stderr, full_command, response)

      response
    end

    private

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
      elsif raise_error && response.error?
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
