# frozen_string_literal: true

module HttpMimic
  class Cookies
    include Enumerable

    CookieItem = Struct.new(:name, :value, :attributes)

    attr_reader :store

    def initialize(cookie_hash = {})
      @store = {}
      @cookie_items = {}

      cookie_hash.each do |k, v|
        self[k] = v
      end
    end

    def [](name)
      @store[name.to_s]
    end

    def []=(name, value)
      @store[name.to_s] = value.to_s
    end

    def item(name)
      @cookie_items[name.to_s]
    end

    def key?(name)
      @store.key?(name.to_s)
    end
    alias has_key? key?
    alias include? key?

    def each(&block)
      @store.each(&block)
    end

    def keys
      @store.keys
    end

    def values
      @store.values
    end

    def empty?
      @store.empty?
    end

    def size
      @store.size
    end
    alias length size

    def delete(name)
      @cookie_items.delete(name.to_s)
      @store.delete(name.to_s)
    end

    def clear
      @cookie_items.clear
      @store.clear
    end

    def merge(other)
      dup_cookies = self.class.new(@store)
      if other.is_a?(Cookies)
        other.each { |k, v| dup_cookies[k] = v }
      elsif other.is_a?(Hash)
        other.each { |k, v| dup_cookies[k] = v }
      end
      dup_cookies
    end

    def merge!(other)
      if other.is_a?(Cookies)
        other.each { |k, v| self[k] = v }
      elsif other.is_a?(Hash)
        other.each { |k, v| self[k] = v }
      end
      self
    end

    def to_h
      @store.dup
    end
    alias to_hash to_h

    def to_cookie_string
      @store.map { |k, v| "#{k}=#{v}" }.join('; ')
    end

    def inspect
      "#<#{self.class.name} #{@store.inspect}>"
    end

    def to_s
      to_cookie_string
    end

    # Parse a Cookies object from Set-Cookie headers
    def self.parse_set_cookie(header_value_or_array)
      cookies = new
      headers = Array(header_value_or_array).flatten.compact

      headers.each do |header_str|
        parts = header_str.split(';').map(&:strip)
        next if parts.empty?

        name_val = parts.first
        key, val = name_val.split('=', 2)
        next unless key

        key = key.strip
        val = val ? val.strip : ''

        attributes = {}
        parts[1..-1].each do |attr_str|
          attr_k, attr_v = attr_str.split('=', 2)
          attr_k = attr_k.strip.downcase
          attributes[attr_k] = attr_v ? attr_v.strip : true
        end

        cookies[key] = val
        cookies.instance_variable_get(:@cookie_items)[key] = CookieItem.new(key, val, attributes)
      end

      cookies
    end

    # Format Hash, Cookies, or String into a curl -b cookie string
    def self.format(cookie_input)
      case cookie_input
      when Hash
        cookie_input.map { |k, v| "#{k}=#{v}" }.join('; ')
      when Cookies
        cookie_input.to_cookie_string
      when String
        cookie_input
      else
        cookie_input.to_s
      end
    end
  end
end
