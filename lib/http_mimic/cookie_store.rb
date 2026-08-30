# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'uri'

module HttpMimic
  class CookieStore
    DEFAULT_TTL = 7200 # 2 hours

    class << self
      def store_dir
        File.expand_path(HttpMimic.configuration.cookie_store_dir || '~/.http_mimic/cookies')
      end

      def cookie_file_for(host)
        clean_host = sanitize_host(host)
        File.join(store_dir, "#{clean_host}.json")
      end

      # Load cookies for a given host
      # Returns a Hash of cookies if valid and not expired, or empty Hash
      def load(host, max_age: DEFAULT_TTL)
        file = cookie_file_for(host)
        return {} unless File.file?(file)

        data = nil
        File.open(file, File::RDONLY) do |f|
          f.flock(File::LOCK_SH)
          data = JSON.parse(f.read) rescue nil
        end

        return {} unless data.is_a?(Hash)

        updated_at = data['updated_at'].to_i
        if !max_age.nil?
          return {} if (Time.now.to_i - updated_at) > max_age
        end

        data['cookies'] || {}
      rescue StandardError => e
        if HttpMimic.configuration.debug
          puts "[HttpMimic::CookieStore] Error loading cookies for #{host}: #{e.message}"
        end
        {}
      end

      # Save cookies for a given host with atomic locking
      def save(host, cookies, ttl: DEFAULT_TTL)
        return if cookies.nil? || cookies.empty?

        clean_host = sanitize_host(host)
        dir = store_dir
        FileUtils.mkdir_p(dir)

        file = cookie_file_for(clean_host)
        existing_cookies = load(clean_host, max_age: ttl) || {}

        new_cookies = cookies.is_a?(Cookies) ? cookies.to_h : cookies.dup
        merged = existing_cookies.merge(stringify_keys(new_cookies))

        payload = {
          'host' => clean_host,
          'updated_at' => Time.now.to_i,
          'ttl' => ttl,
          'cookies' => merged
        }

        # Thread & Process safe atomic write
        tmp_file = "#{file}.tmp.#{Process.pid}_#{Time.now.to_f}"
        File.open(tmp_file, File::RDWR | File::CREAT, 0644) do |f|
          f.flock(File::LOCK_EX)
          f.write(JSON.pretty_generate(payload))
          f.flush
        end
        File.rename(tmp_file, file)
      rescue StandardError => e
        FileUtils.rm_f(tmp_file) if tmp_file
        if HttpMimic.configuration.debug
          puts "[HttpMimic::CookieStore] Error saving cookies for #{host}: #{e.message}"
        end
      end

      # Clear stored cookies for a host or all hosts
      def clear(host = nil)
        if host
          file = cookie_file_for(host)
          FileUtils.rm_f(file)
        else
          FileUtils.rm_rf(store_dir)
        end
      end

      # Extract host from URL or host string
      def extract_host(url_or_host)
        str = url_or_host.to_s.strip
        if str =~ %r{^https?://}i
          URI.parse(str).host
        else
          str.split(':').first
        end
      rescue StandardError
        str
      end

      private

      def sanitize_host(host)
        h = extract_host(host) || 'default'
        h.gsub(/[^a-zA-Z0-9.\-_]/, '_')
      end

      def stringify_keys(hash)
        hash.each_with_object({}) { |(k, v), h| h[k.to_s] = v.to_s }
      end
    end
  end
end
