# frozen_string_literal: true

module HttpMimic
  # 基礎例外類別
  class Error < StandardError; end

  # 當找不到 curl-impersonate 執行檔時拋出
  class BinaryNotFoundError < Error; end

  # 當 curl 執行失敗或非 0 exit status 時拋出
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

  # 連線超時 (Curl exit code 28)
  class TimeoutError < CommandError; end

  # 連線失敗或 DNS 無法解析 (Curl exit code 6, 7, 52 等)
  class ConnectionError < CommandError; end

  # SSL/TLS 握手或憑證錯誤 (Curl exit code 35, 51, 60 等)
  class SSLError < CommandError; end

  # 回應解析失敗
  class ResponseParseError < Error; end
end
