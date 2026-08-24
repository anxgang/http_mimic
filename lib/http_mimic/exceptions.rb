# frozen_string_literal: true

module HttpMimic
  # Base exception class
  class Error < StandardError; end

  # Raised when the curl-impersonate binary cannot be found
  class BinaryNotFoundError < Error; end

  # Raised when the curl command fails or returns a non-zero exit status
  class CommandError < Error
    attr_reader :exit_code, :stderr, :command, :response

    def initialize(message, exit_code: nil, stderr: nil, command: nil, response: nil)
      super(message)
      @exit_code = exit_code
      @stderr = stderr
      @command = command
      @response = response
    end
  end

  # Connection timeout (Curl exit code 28)
  class TimeoutError < CommandError; end

  # Connection failure or DNS resolution error (Curl exit code 6, 7, 52, etc.)
  class ConnectionError < CommandError; end

  # SSL/TLS handshake or certificate error (Curl exit code 35, 51, 60, etc.)
  class SSLError < CommandError; end

  # Raised when response parsing fails
  class ResponseParseError < Error; end
end
