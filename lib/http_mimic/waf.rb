# frozen_string_literal: true

require 'http_mimic/waf/detector'
require 'http_mimic/waf/akamai_solver'
require 'http_mimic/waf/google_solver'

module HttpMimic
  module Waf
    class << self
      def solve(url, response, options = {})
        waf_type = Detector.detect(response)
        return nil unless waf_type

        case waf_type
        when :akamai
          AkamaiSolver.solve(url, response, options)
        when :google
          GoogleSolver.solve(url, response, options)
        else
          nil
        end
      end
    end
  end
end
