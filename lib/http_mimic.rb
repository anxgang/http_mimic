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

    # 手動下載 / 安裝 curl-impersonate 二進制執行檔
    def download_driver!(version: nil, force: false)
      Downloader.download!(version: version, force: force)
    end

    # 檢查本地是否已安裝 curl-impersonate
    def driver_installed?(version: nil)
      Downloader.installed?(version: version)
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
