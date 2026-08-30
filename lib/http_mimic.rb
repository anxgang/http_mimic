# frozen_string_literal: true

require 'open3'
require 'uri'
require 'json'

require 'http_mimic/version'
require 'http_mimic/exceptions'
require 'http_mimic/configuration'
require 'http_mimic/downloader'
require 'http_mimic/headers'
require 'http_mimic/cookies'
require 'http_mimic/response'
require 'http_mimic/response_parser'
require 'http_mimic/command_builder'
require 'http_mimic/request'
require 'http_mimic/client'
require 'http_mimic/module_methods'
require 'http_mimic/js_runtime'
require 'http_mimic/waf'
require 'http_mimic/cookie_store'

module HttpMimic
  extend ModuleMethods

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    # Manually download and install curl-impersonate binary driver
    def download_driver!(version: nil, force: false)
      Downloader.download!(version: version, force: force)
    end

    # Check if curl-impersonate driver is installed locally
    def driver_installed?(version: nil)
      Downloader.installed?(version: version)
    end

    # Manually download and install QuickJS binary driver
    def download_qjs!(version: nil, force: false)
      Downloader.download_qjs!(version: version, force: force)
    end

    # Check if QuickJS driver is installed locally
    def qjs_installed?(version: nil)
      Downloader.qjs_installed?(version: version)
    end

    # Return local path to QuickJS binary
    def qjs_path
      Downloader.qjs_path
    end

    # Evaluate JavaScript code using QuickJS
    def eval_js(code, options = {})
      JSRuntime.eval(code, timeout: options[:timeout], install_dir: options[:install_dir], auto_download: options[:auto_download])
    end

    # Evaluate JavaScript and auto-parse JSON result
    def eval_js_json(code, options = {})
      JSRuntime.eval_json(code, timeout: options[:timeout], install_dir: options[:install_dir], auto_download: options[:auto_download])
    end

    # Automatically detect WAF type from response
    def detect_waf(response)
      Waf::Detector.detect(response)
    end

    # Attempt to solve WAF challenge for a blocked response
    def solve_waf(url, response, options = {})
      Waf.solve(url, response, options)
    end

    # Persistent Host CookieStore helpers
    def load_cookies(host, max_age: nil)
      CookieStore.load(host, max_age: max_age)
    end

    def save_cookies(host, cookies, ttl: nil)
      CookieStore.save(host, cookies, ttl: ttl || CookieStore::DEFAULT_TTL)
    end

    def clear_cookies!(host = nil)
      CookieStore.clear(host)
    end

    def included(base)
      base.extend(ModuleMethods)
      base.send(:include, InstanceMethods)
    end
  end

  module InstanceMethods
    def get(url, options = {})
      self.class.get(url, options)
    end

    def post(url, options = {})
      self.class.post(url, options)
    end

    def put(url, options = {})
      self.class.put(url, options)
    end

    def patch(url, options = {})
      self.class.patch(url, options)
    end

    def delete(url, options = {})
      self.class.delete(url, options)
    end

    def head(url, options = {})
      self.class.head(url, options)
    end

    def options(url, options = {})
      self.class.options(url, options)
    end

    def request(method, url, options = {})
      self.class.request(method, url, options)
    end
  end
end
