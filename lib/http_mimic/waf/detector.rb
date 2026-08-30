# frozen_string_literal: true

module HttpMimic
  module Waf
    class Detector
      class << self
        def detect(response)
          return nil unless response

          if akamai?(response)
            :akamai
          elsif google?(response)
            :google
          elsif cloudflare?(response)
            :cloudflare
          elsif datadome?(response)
            :datadome
          else
            nil
          end
        end

        def challenge_page?(response)
          return false unless response
          body = response.body.to_s
          return true if body.include?('sec-if-cpt-container') || body.include?('sec-bc-button-parent')
          return true if body.include?('challenges.cloudflare.com') || body.include?('cf-turnstile')
          return true if body.include?('datadome.captcha') || body.include?('geo.captcha-delivery.com')
          return true if body.include?('/httpservice/retry/enablejs') || (body.include?('knitsail') && body.include?('SG_SS'))
          false
        end

        def google?(response)
          return false unless response
          body = response.body.to_s
          return true if body.include?('/httpservice/retry/enablejs')
          return true if body.include?('knitsail') && body.include?('SG_SS')
          return true if response.headers['server']&.downcase&.include?('gws') && body.include?('enablejs')
          false
        end

        def akamai?(response)
          return true if response.headers['set-cookie']&.include?('_abck=')
          return true if response.cookies.key?('_abck') || response.cookies.key?('bm_sz') || response.cookies.key?('ak_bmsc')
          return true if response.headers['x-akamai-transformed'] || response.headers['x-reference-error']

          body = response.body.to_s
          return true if body.include?('Reference Error:') && body.include?('Akamai')
          return true if body.include?('bmak') || body.include?('sensor_data')
          return true if body.include?('sec-if-cpt-container') || body.include?('sec-bc-button-parent')
          return true if body =~ /<script[^>]*src=["\x27]([^"\x27]*\/[a-zA-Z0-9_-]{10,}\?[a-zA-Z0-9_=-]+)["\x27]/

          false
        end

        def cloudflare?(response)
          return true if response.headers['server']&.downcase&.include?('cloudflare')
          return true if response.headers['cf-ray'] || response.cookies.key?('cf_clearance')
          return true if response.body.to_s.include?('challenges.cloudflare.com')

          false
        end

        def datadome?(response)
          return true if response.headers['x-datadome'] || response.cookies.key?('datadome')
          return true if response.headers['server']&.downcase&.include?('datadome')

          false
        end
      end
    end
  end
end
