# frozen_string_literal: true

require 'json'
require 'uri'

module HttpMimic
  module Waf
    class GoogleSolver
      class << self
        def solve(target_url, response, options = {})
          return nil unless response

          html = response.body.to_s
          return nil if html.empty?

          uri = URI.parse(target_url) rescue nil
          base_url = uri ? "#{uri.scheme}://#{uri.host}" : "https://www.google.com"

          impersonate = options[:impersonate] || HttpMimic.configuration.default_impersonate || 'chrome131'
          current_cookies = (response.cookies || Cookies.new).dup

          # Strategy 1: Session warmup from Google root if cookies are sparse
          if current_cookies.empty? || !current_cookies.key?('NID')
            warmup_resp = HttpMimic.get(
              "#{base_url}/",
              impersonate: impersonate,
              cookies: current_cookies,
              auto_fallback: false,
              solve_waf: false,
              persist_cookies: false
            )
            warmup_resp.cookies.each { |k, v| current_cookies[k] = v } if warmup_resp&.cookies
          end

          # Strategy 2: Attempt QuickJS solve if script payload exists
          scripts = html.scan(/<script[^>]*>([\s\S]*?)<\/script>/i).map(&:first)
          if scripts.any? { |s| s.include?('knitsail') || s.include?('SG_SS') || s.include?('closureDynamicButton') }
            sg_ss_cookie = solve_with_quickjs(target_url, scripts, current_cookies)
            current_cookies['SG_SS'] = sg_ss_cookie if sg_ss_cookie && !sg_ss_cookie.start_with?('E:')
          end

          # Strategy 3: Retry search query with same-origin referral headers and updated cookies
          retry_headers = (options[:headers] || {}).dup
          retry_headers['Referer'] ||= "#{base_url}/"
          retry_headers['sec-fetch-site'] ||= 'same-origin'

          retry_opts = options.merge(
            cookies: current_cookies,
            headers: retry_headers,
            auto_fallback: false,
            solve_waf: false
          )

          HttpMimic.get(target_url, **retry_opts)
        rescue StandardError => e
          HttpMimic.logger.debug("[HttpMimic::Waf::GoogleSolver] Failed to solve Google challenge: #{e.message}") if HttpMimic.logger
          nil
        end

        private

        def solve_with_quickjs(target_url, scripts, cookies)
          context_js_path = File.expand_path('browser_context.js', __dir__)
          context_js = File.read(context_js_path)
          cookie_str = cookies.respond_to?(:to_cookie_string) ? cookies.to_cookie_string : cookies.to_s

          driver_script = <<~JS
            globalThis.__TARGET_URL__ = #{target_url.to_json};
            globalThis.__DOCUMENT_TITLE__ = "Google Search";
            globalThis.__INITIAL_COOKIES__ = #{cookie_str.to_json};
            globalThis.__REFERRER__ = "https://www.google.com/";

            #{context_js}

            // Google specific environment enhancements
            globalThis.sessionStorage = {
              _data: {},
              getItem(k) { return this._data[k] || null; },
              setItem(k, v) { this._data[k] = String(v); },
              removeItem(k) { delete this._data[k]; },
              clear() { this._data = {}; }
            };
            globalThis.localStorage = globalThis.sessionStorage;
            globalThis._F_css = function() {};
            globalThis.google = { c: { c: { a: true } } };

            #{scripts.join("\n;\n")}

            // Extract p token and invoke knitsail if present
            var allScripts = #{scripts.join("\n").to_json};
            var pMatch = allScripts.match(/var p=\\x27([^\\x27]+)\\x27/);
            var pVal = pMatch ? pMatch[1] : null;

            var solved_token = null;
            if (globalThis.knitsail && typeof globalThis.knitsail.a === "function" && pVal) {
              try {
                globalThis.knitsail.a(pVal, function(resultCallback) {
                  if (typeof resultCallback === "function") {
                    resultCallback(function(token) {
                      solved_token = token;
                    }, [{}]);
                  }
                }, false, undefined, undefined, undefined, undefined, true);
              } catch(e) {}
            }

            if (typeof globalThis.__drainEventLoop === "function") {
              globalThis.__drainEventLoop(50);
            }

            JSON.stringify({
              token: solved_token
            });
          JS

          result = JSRuntime.eval_json(driver_script)
          result ? result['token'] : nil
        rescue StandardError
          nil
        end
      end
    end
  end
end
