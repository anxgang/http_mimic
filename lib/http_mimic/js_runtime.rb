# frozen_string_literal: true

require 'open3'
require 'json'
require 'timeout'

module HttpMimic
  class JSRuntime
    STDIN_RUNNER = <<~JS
      const input = std.in.readAsString();
      const result = eval(input);
      if (result !== undefined) {
        if (typeof result === "object" && result !== null) {
          console.log(JSON.stringify(result));
        } else {
          console.log(result);
        }
      }
    JS

    class << self
      def eval(js_code, timeout: nil, install_dir: nil, auto_download: nil)
        ensure_qjs_installed!(install_dir: install_dir, auto_download: auto_download)

        qjs_bin = Downloader.qjs_path(install_dir: install_dir)
        raise BinaryNotFoundError, "QuickJS binary 'qjs' not found. Run HttpMimic.download_qjs! to install." unless qjs_bin

        cmd = [qjs_bin, '--std', '-e', STDIN_RUNNER]
        effective_timeout = timeout || HttpMimic.configuration.default_timeout

        stdout = nil
        stderr = nil
        status = nil

        begin
          if effective_timeout && effective_timeout > 0
            Timeout.timeout(effective_timeout) do
              stdout, stderr, status = Open3.capture3(*cmd, stdin_data: js_code.to_s)
            end
          else
            stdout, stderr, status = Open3.capture3(*cmd, stdin_data: js_code.to_s)
          end
        rescue Timeout::Error
          raise JSTimeoutError.new("JavaScript execution timed out after #{effective_timeout}s")
        end

        unless status && status.success?
          raise JSError.new(
            "JavaScript execution failed: #{stderr.to_s.strip}",
            stderr: stderr,
            exit_code: status ? status.exitstatus : nil
          )
        end

        stdout.to_s.strip
      end

      def eval_json(js_code, timeout: nil, install_dir: nil, auto_download: nil)
        output = eval(js_code, timeout: timeout, install_dir: install_dir, auto_download: auto_download)
        return nil if output.nil? || output.empty?

        JSON.parse(output)
      rescue JSON::ParserError => e
        raise ResponseParseError, "Failed to parse JavaScript JSON output: #{e.message} (Output: #{output.inspect})"
      end

      private

      def ensure_qjs_installed!(install_dir: nil, auto_download: nil)
        should_download = auto_download.nil? ? HttpMimic.configuration.auto_download : auto_download
        return unless should_download
        return if Downloader.qjs_installed?(install_dir: install_dir)

        Downloader.download_qjs!(install_dir: install_dir)
      end
    end
  end
end
