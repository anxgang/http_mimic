# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'set'

module HttpMimic
  class ProxyPool
    DEFAULT_SOURCES = [
      'https://raw.githubusercontent.com/monosans/proxy-list/main/proxies/http.txt',
      'https://api.proxyscrape.com/v2/?request=displayproxies&protocol=http&timeout=5000&country=all&ssl=all&anonymity=all',
      'https://raw.githubusercontent.com/TheSpeedX/SOCKS-List/master/http.txt'
    ].freeze

    class << self
      def instance
        @instance ||= new
      end

      def reset_instance!
        @instance = nil
      end

      def get
        instance.get
      end
      alias sample get
      alias next_proxy get

      def mark_dead(proxy)
        instance.mark_dead(proxy)
      end

      def mark_alive(proxy)
        instance.mark_alive(proxy)
      end

      def refresh!(force: true)
        instance.refresh!(force: force)
      end

      def load(proxies)
        instance.load(proxies)
      end

      def all
        instance.all
      end

      def available
        instance.available
      end

      def dead_proxies
        instance.dead_proxies
      end

      def size
        instance.size
      end

      def clear!
        instance.clear!
      end
    end

    attr_reader :sources, :ttl, :timeout
    attr_accessor :proxies

    def initialize(options = {})
      config = HttpMimic.configuration rescue nil
      @sources = options[:sources] || config&.proxy_sources || DEFAULT_SOURCES.dup
      @ttl = options[:ttl] || config&.proxy_pool_ttl || 1800
      @timeout = options[:timeout] || config&.proxy_timeout || 5
      @proxies = []
      @dead_proxies = Set.new
      @last_fetched_at = nil
      @mutex = Mutex.new
    end

    # Retrieve an available proxy from the pool
    #
    # @return [String, nil] Proxy URL (e.g. 'http://1.2.3.4:8080') or nil if none available
    def get
      @mutex.synchronize do
        refresh_unlocked(force: false) if should_refresh_unlocked?
        avail = @proxies - @dead_proxies.to_a
        if avail.empty? && !@proxies.empty?
          # If all current proxies are exhausted/dead, clear dead set and try one more refresh
          @dead_proxies.clear
          refresh_unlocked(force: true)
          avail = @proxies - @dead_proxies.to_a
        end
        avail.sample
      end
    end
    alias sample get
    alias next_proxy get

    # Mark a proxy as dead/unusable
    #
    # @param proxy [String]
    def mark_dead(proxy)
      return unless proxy
      @mutex.synchronize do
        @dead_proxies.add(normalize_proxy(proxy))
      end
    end

    # Mark a proxy as active/usable
    #
    # @param proxy [String]
    def mark_alive(proxy)
      return unless proxy
      @mutex.synchronize do
        @dead_proxies.delete(normalize_proxy(proxy))
      end
    end

    # Explicitly refresh proxy pool from configured sources
    def refresh!(force: true)
      @mutex.synchronize do
        refresh_unlocked(force: force)
      end
    end

    # Manually load a custom array of proxies
    #
    # @param proxy_list [Array<String>]
    def load(proxy_list)
      @mutex.synchronize do
        @proxies = Array(proxy_list).map { |p| normalize_proxy(p) }.compact.uniq
        @dead_proxies.clear
        @last_fetched_at = Time.now
      end
    end

    # Returns all loaded proxies
    def all
      @mutex.synchronize { @proxies.dup }
    end

    # Returns all non-dead available proxies
    def available
      @mutex.synchronize { (@proxies - @dead_proxies.to_a).dup }
    end

    # Returns dead proxies
    def dead_proxies
      @mutex.synchronize { @dead_proxies.to_a }
    end

    # Number of available proxies
    def size
      @mutex.synchronize { (@proxies - @dead_proxies.to_a).size }
    end

    # Reset proxy pool
    def clear!
      @mutex.synchronize do
        @proxies.clear
        @dead_proxies.clear
        @last_fetched_at = nil
      end
    end

    private

    def should_refresh_unlocked?
      @proxies.empty? || @last_fetched_at.nil? || (Time.now - @last_fetched_at > @ttl)
    end

    def refresh_unlocked(force: false)
      return if !force && !should_refresh_unlocked?

      new_proxies = fetch_from_sources
      if !new_proxies.empty?
        @proxies = new_proxies
        @last_fetched_at = Time.now
      end
    end

    def fetch_from_sources
      collected = []
      sources_to_try = Array(@sources).empty? ? DEFAULT_SOURCES : @sources

      sources_to_try.each do |source_url|
        begin
          uri = URI.parse(source_url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == 'https')
          http.open_timeout = @timeout
          http.read_timeout = @timeout

          req = Net::HTTP::Get.new(uri.request_uri)
          req['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'

          res = http.request(req)
          if res.is_a?(Net::HTTPSuccess) && res.body
            # Extract IP:PORT matches
            ips = res.body.scan(/\b(?:\d{1,3}\.){3}\d{1,3}:\d{2,5}\b/)
            if !ips.empty?
              collected.concat(ips.take(150))
              # Stop early if we have collected enough proxies
              break if collected.size >= 50
            end
          end
        rescue StandardError => e
          if HttpMimic.configuration.debug
            puts "[HttpMimic::ProxyPool] Failed to fetch proxy list from #{source_url}: #{e.message}"
          end
        end
      end

      collected.uniq.map { |p| normalize_proxy(p) }
    end

    def normalize_proxy(proxy)
      p = proxy.to_s.strip
      return nil if p.empty?
      p.start_with?('http://', 'https://', 'socks5://', 'socks4://') ? p : "http://#{p}"
    end
  end
end
