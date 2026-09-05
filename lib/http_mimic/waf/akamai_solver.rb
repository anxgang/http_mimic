# frozen_string_literal: true

require 'uri'
require 'json'

module HttpMimic
  module Waf
    class AkamaiSolver
      CONTEXT_JS_PATH = File.expand_path('browser_context.js', __dir__)

      class << self
        def solve(target_url, initial_response, options = {})
          cookies = initial_response.cookies.dup
          impersonate = options[:impersonate] || HttpMimic.configuration.default_impersonate || 'chrome131'

          sensor_script_url = extract_sensor_script_url(target_url, initial_response.body)
          return nil unless sensor_script_url

          # 1. Fetch the dynamic sensor script
          script_resp = HttpMimic.get(
            sensor_script_url,
            impersonate: impersonate,
            cookies: cookies,
            headers: { 'Referer' => target_url },
            auto_fallback: false,
            solve_waf: false
          )
          return nil unless script_resp.success?

          sensor_js = script_resp.body
          context_js = File.read(CONTEXT_JS_PATH)

          doc_title = initial_response.title.to_s
          user_agent = options[:user_agent]
          referer = (options[:headers] || {})['Referer'] || (options[:headers] || {})['referer'] || target_url

          # 2. Phase 1: Virtual browser simulation inside QuickJS (initial telemetry)
          driver_script_1 = build_driver_script(
            target_url: target_url,
            doc_title: doc_title,
            cookie_str: cookies.to_cookie_string,
            referer: referer,
            user_agent: user_agent,
            context_js: context_js,
            sensor_js: sensor_js,
            phase: 1
          )

          result1 = JSRuntime.eval_json(driver_script_1)
          sensor_posts_1 = result1 && result1['sensor_posts']
          return nil if sensor_posts_1.nil? || sensor_posts_1.empty?

          # 3. Post Phase 1 sensor data to Akamai endpoint
          updated_cookies = cookies.dup
          post_sensor_data(sensor_script_url, target_url, impersonate, updated_cookies, sensor_posts_1)

          # 4. Phase 2: If _abck is not verified yet (~0~), perform second round after short pause
          if !verified_abck?(updated_cookies)
            sleep 0.8
            driver_script_2 = build_driver_script(
              target_url: target_url,
              doc_title: doc_title,
              cookie_str: updated_cookies.to_cookie_string,
              referer: referer,
              user_agent: user_agent,
              context_js: context_js,
              sensor_js: sensor_js,
              phase: 2
            )

            result2 = JSRuntime.eval_json(driver_script_2)
            sensor_posts_2 = result2 && result2['sensor_posts']
            if sensor_posts_2 && !sensor_posts_2.empty?
              post_sensor_data(sensor_script_url, target_url, impersonate, updated_cookies, sensor_posts_2)
            end
          end

          # 5. Retry original target URL with the updated cookies
          retry_headers = (options[:headers] || {}).merge('Referer' => target_url)
          HttpMimic.get(
            target_url,
            options.merge(
              cookies: updated_cookies,
              headers: retry_headers,
              auto_fallback: false,
              solve_waf: false
            )
          )
        rescue StandardError => e
          if HttpMimic.configuration.debug
            puts "[HttpMimic::Waf::AkamaiSolver] Error solving Akamai challenge: #{e.message}"
          end
          nil
        end

        def build_driver_script(params)
          <<~JS
            globalThis.__TARGET_URL__ = #{params[:target_url].to_json};
            globalThis.__DOCUMENT_TITLE__ = #{params[:doc_title].to_json};
            globalThis.__INITIAL_COOKIES__ = #{params[:cookie_str].to_json};
            globalThis.__REFERRER__ = #{params[:referer].to_json};
            #{params[:user_agent] ? "globalThis.__USER_AGENT__ = #{params[:user_agent].to_json};" : ""}
            globalThis.__TELEMETRY_PHASE__ = #{params[:phase] || 1};

            #{params[:context_js]}
            #{params[:sensor_js]}

            if (typeof globalThis.__simulateHumanInteractions === "function") {
              globalThis.__simulateHumanInteractions();
            }
            if (typeof globalThis.__drainEventLoop === "function") {
              globalThis.__drainEventLoop(100);
            }

            JSON.stringify({
              sensor_posts: globalThis.__sensor_posts
            });
          JS
        end

        def post_sensor_data(sensor_script_url, target_url, impersonate, updated_cookies, sensor_posts)
          origin_url = URI.parse(target_url).tap { |u| u.path = ''; u.query = nil }.to_s rescue target_url
          sensor_posts.each do |post|
            post_body = post['body']
            next if post_body.nil? || post_body.empty?

            post_resp = HttpMimic.post(
              sensor_script_url,
              impersonate: impersonate,
              cookies: updated_cookies,
              headers: {
                'Content-Type' => 'text/plain;charset=UTF-8',
                'Referer' => target_url,
                'Origin' => origin_url,
                'Accept' => '*/*'
              },
              body: post_body,
              auto_fallback: false,
              solve_waf: false
            )

            post_resp.cookies.each { |k, v| updated_cookies[k] = v } if post_resp&.cookies
          end
        end

        def verified_abck?(cookies)
          return false unless cookies
          abck = cookies['_abck'] || (cookies.respond_to?(:key?) && cookies['_abck'])
          abck.to_s.include?('~0~')
        end

        def extract_sensor_script_url(target_url, html)
          return nil if html.nil? || html.empty?

          match = html.match(/<script[^>]*src=["\x27]([^"\x27]*\/[a-zA-Z0-9_-]{10,}\?[a-zA-Z0-9_=-]+)["\x27]/i)
          match ||= html.match(/<script[^>]*src=["\x27]([^"\x27]*akam[^"\x27]*)["\x27]/i)
          match ||= html.match(/<script[^>]*src=["\x27]([^"\x27]*\/[a-zA-Z0-9_\-\/]+\?v=[a-zA-Z0-9_-]+)["\x27]/i)

          return nil unless match

          URI.join(target_url, match[1]).to_s
        rescue StandardError
          nil
        end
      end
    end
  end
end
