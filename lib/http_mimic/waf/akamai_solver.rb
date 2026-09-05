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
          profile = options[:profile]
          impersonate = resolve_impersonate_target(profile, options[:impersonate])
          user_agent = resolve_user_agent(impersonate, options[:user_agent])

          sensor_script_urls = extract_sensor_script_urls(target_url, initial_response.body)
          return nil if sensor_script_urls.empty?

          # 1. Fetch all dynamic sensor scripts in order
          scripts_data = []
          sensor_script_urls.each do |s_url|
            s_resp = HttpMimic.get(
              s_url,
              impersonate: impersonate,
              cookies: cookies,
              headers: { 'Referer' => target_url, 'User-Agent' => user_agent },
              proxy: options[:proxy],
              auto_fallback: false,
              solve_waf: false,
              debug: options[:debug]
            )
            scripts_data << { url: s_url, body: s_resp.body } if s_resp.success?
          end
          return nil if scripts_data.empty?

          context_js = File.read(CONTEXT_JS_PATH)
          doc_title = initial_response.title.to_s
          referer = (options[:headers] || {})['Referer'] || (options[:headers] || {})['referer'] || target_url
          cpt_script_url = sensor_script_urls.find { |u| u.include?('t=') } || sensor_script_urls.first

          # 2. Phase 1: Virtual browser simulation inside QuickJS (initial telemetry)
          driver_script_1 = build_driver_script(
            target_url: target_url,
            doc_title: doc_title,
            cookie_str: cookies.to_cookie_string,
            referer: referer,
            user_agent: user_agent,
            context_js: context_js,
            scripts_data: scripts_data,
            phase: 1
          )

          result1 = JSRuntime.eval_json(driver_script_1)
          sensor_posts_1 = result1 && result1['sensor_posts']
          return nil if sensor_posts_1.nil? || sensor_posts_1.empty?

          # 3. Post Phase 1 sensor data to Akamai endpoint
          updated_cookies = cookies.dup
          post_sensor_data(cpt_script_url, target_url, impersonate, updated_cookies, sensor_posts_1, user_agent: user_agent, proxy: options[:proxy], debug: options[:debug], cpt_url: cpt_script_url)

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
              scripts_data: scripts_data,
              phase: 2
            )

            result2 = JSRuntime.eval_json(driver_script_2)
            sensor_posts_2 = result2 && result2['sensor_posts']
            if sensor_posts_2 && !sensor_posts_2.empty?
              post_sensor_data(cpt_script_url, target_url, impersonate, updated_cookies, sensor_posts_2, user_agent: user_agent, proxy: options[:proxy], debug: options[:debug], cpt_url: cpt_script_url)
            end
          end

          # 5. Retry original target URL with the updated cookies
          retry_headers = (options[:headers] || {}).merge('Referer' => target_url, 'User-Agent' => user_agent)
          HttpMimic.get(
            target_url,
            options.merge(
              profile: profile,
              impersonate: impersonate,
              cookies: updated_cookies,
              headers: retry_headers,
              user_agent: user_agent,
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

        def resolve_impersonate_target(profile, explicit_imp = nil)
          return explicit_imp.to_s if explicit_imp && !explicit_imp.empty?

          case profile&.to_sym
          when :android, :mobile
            'chrome131_android'
          when :ios
            'safari260_ios'
          when :firefox
            'firefox135'
          when :safari
            'safari180'
          else
            HttpMimic.configuration.default_impersonate || 'chrome131'
          end
        end

        def resolve_user_agent(impersonate, explicit_ua = nil)
          return explicit_ua if explicit_ua && !explicit_ua.empty?

          imp = impersonate.to_s.downcase
          if imp.include?('android')
            ver = imp[/\d+/] || '131'
            "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/#{ver}.0.0.0 Mobile Safari/537.36"
          elsif imp.include?('ios') || imp.include?('iphone') || imp.include?('ipad')
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
          elsif imp.include?('chrome')
            ver = imp[/\d+/] || '150'
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/#{ver}.0.0.0 Safari/537.36"
          elsif imp.include?('firefox')
            ver = imp[/\d+/] || '135'
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:#{ver}.0) Gecko/20100101 Firefox/#{ver}.0"
          elsif imp.include?('safari')
            ver = imp[/\d+/] || '18_0'
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/#{ver.tr('_', '.')} Safari/605.1.15"
          else
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36"
          end
        end

        def build_driver_script(params)
          scripts_code = if params[:scripts_data] && !params[:scripts_data].empty?
            params[:scripts_data].map.with_index do |s, idx|
              tag_var = "sTag_#{idx}"
              <<~SCRIPT_EVAL
                const #{tag_var} = document.createElement('script');
                #{tag_var}.src = #{s[:url].to_json};
                document.body.appendChild(#{tag_var});
                document.currentScript = #{tag_var};
                try {
                  ;\n#{s[:body]}\n;
                } catch(e) {}
              SCRIPT_EVAL
            end.join("\n")
          else
            ";\n#{params[:sensor_js]}\n;"
          end


          <<~JS
            globalThis.__TARGET_URL__ = #{params[:target_url].to_json};
            globalThis.__DOCUMENT_TITLE__ = #{params[:doc_title].to_json};
            globalThis.__INITIAL_COOKIES__ = #{params[:cookie_str].to_json};
            globalThis.__REFERRER__ = #{params[:referer].to_json};
            #{params[:user_agent] ? "globalThis.__USER_AGENT__ = #{params[:user_agent].to_json};" : ""}
            globalThis.__TELEMETRY_PHASE__ = #{params[:phase] || 1};

            #{params[:context_js]}
            ;

            #{scripts_code}

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

        def post_sensor_data(sensor_script_url, target_url, impersonate, updated_cookies, sensor_posts, user_agent: nil, proxy: nil, debug: nil, cpt_url: nil)
          origin_url = URI.parse(target_url).tap { |u| u.path = ''; u.query = nil }.to_s rescue target_url
          sensor_posts.each do |post|
            post_body = post['body']
            method = (post['method'] || 'POST').to_s.upcase
            next if method == 'POST' && (post_body.nil? || post_body.empty?)

            post_url = if post['url'].to_s.empty?
              cpt_url || target_url
            elsif post['url'].start_with?('http')
              u = post['url']
              if cpt_url && !u.include?('t=') && cpt_url.include?('t=')
                q = URI.parse(cpt_url).query rescue nil
                u = "#{u}?#{q}" if q && !q.empty?
              end
              u
            else
              URI.join(target_url, post['url']).to_s
            end


            content_type = (post['headers'] && (post['headers']['Content-Type'] || post['headers']['content-type'])) || 'application/json'

            post_headers = {
              'Referer' => target_url,
              'Origin' => origin_url,
              'Accept' => '*/*',
              'Sec-Fetch-Dest' => 'empty',
              'Sec-Fetch-Mode' => 'cors',
              'Sec-Fetch-Site' => 'same-origin'
            }
            if user_agent.to_s.include?('Chrome')
              is_mobile = user_agent.to_s.include?('Mobile') || user_agent.to_s.include?('Android')
              ver = user_agent[/Chrome\/(\d+)/, 1] || '131'
              post_headers['sec-ch-ua'] = %("Google Chrome";v="#{ver}", "Chromium";v="#{ver}", "Not_A Brand";v="24")
              post_headers['sec-ch-ua-mobile'] = is_mobile ? '?1' : '?0'
              post_headers['sec-ch-ua-platform'] = is_mobile ? '"Android"' : '"macOS"'
            end
            post_headers['Content-Type'] = content_type if method == 'POST'
            post_headers['User-Agent'] = user_agent if user_agent

            post_resp = if method == 'GET'
              HttpMimic.get(
                post_url,
                impersonate: impersonate,
                cookies: updated_cookies,
                headers: post_headers,
                proxy: proxy,
                auto_fallback: false,
                solve_waf: false,
                debug: debug
              )
            else
              HttpMimic.post(
                post_url,
                impersonate: impersonate,
                cookies: updated_cookies,
                headers: post_headers,
                proxy: proxy,
                body: post_body,
                auto_fallback: false,
                solve_waf: false,
                debug: debug
              )
            end

            post_resp.cookies.each { |k, v| updated_cookies[k] = v } if post_resp&.cookies
          end
        end

        def verified_abck?(cookies)
          return false unless cookies
          abck = cookies['_abck'] || (cookies.respond_to?(:key?) && cookies['_abck'])
          return true if abck.to_s.include?('~0~')

          bm_sc = cookies['bm_sc'] || (cookies.respond_to?(:key?) && cookies['bm_sc'])
          return true if bm_sc.to_s.include?('~0~0~0') && !bm_sc.to_s.start_with?('3~')

          false
        end

        def extract_sensor_script_url(target_url, html)
          return nil if html.nil? || html.empty?

          match = html.match(/<script[^>]*src=["\x27]([^"\x27]*\/[a-zA-Z0-9_\-\/]+\?[^"\x27\s>]+)["\x27]/i)
          match ||= html.match(/<script[^>]*src=["\x27]([^"\x27]*akam[^"\x27]*)["\x27]/i)
          match ||= html.match(/<script[^>]*src=["\x27]([^"\x27]*\/[a-zA-Z0-9_-]{10,}\?[a-zA-Z0-9_=-]+)["\x27]/i)

          return nil unless match

          raw_url = match[1].gsub('&amp;', '&')
          URI.join(target_url, raw_url).to_s
        rescue StandardError
          nil
        end

        def extract_sensor_script_urls(target_url, html)
          return [] if html.nil? || html.empty?

          matches = html.scan(/<script[^>]*src=["\x27]([^"\x27]+)["\x27]/i).flatten
          akamai_scripts = matches.select do |src|
            src =~ /\/GPv76/i || src =~ /akam/i || src =~ /\/[a-zA-Z0-9_-]{10,}\?[a-zA-Z0-9_=-]+/i || src =~ /_bm\//i
          end

          if akamai_scripts.empty?
            single = extract_sensor_script_url(target_url, html)
            return single ? [single] : []
          end

          akamai_scripts.map do |raw_src|
            URI.join(target_url, raw_src.gsub('&amp;', '&')).to_s
          rescue StandardError
            nil
          end.compact
        end
      end
    end
  end
end
