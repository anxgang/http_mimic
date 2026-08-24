# frozen_string_literal: true

module HttpMimic
  # Case-insensitive HTTP Headers wrapper that preserves original casing
  class Headers
    include Enumerable

    def initialize(headers_hash = {})
      @headers = {}
      @names = {}
      @multi_values = {}

      headers_hash.each do |key, val|
        self[key] = val
      end
    end

    def [](key)
      return nil if key.nil?
      canonical = @names[normalize_key(key)]
      return nil unless canonical

      norm_key = normalize_key(key)
      if norm_key == 'set-cookie' && @multi_values.key?(norm_key)
        # For Set-Cookie, return an Array if multiple values exist
        @multi_values[norm_key].size > 1 ? @multi_values[norm_key] : @multi_values[norm_key].first
      else
        @headers[canonical]
      end
    end

    def []=(key, value)
      return if key.nil?
      norm = normalize_key(key)
      if existing_key = @names[norm]
        @headers.delete(existing_key)
      end
      orig_key = key.to_s
      @names[norm] = orig_key
      @headers[orig_key] = value

      @multi_values[norm] = value.is_a?(Array) ? value.dup : [value]
    end

    # Add header (supports duplicate headers with the same name, e.g., multiple Set-Cookie entries)
    def add(key, value)
      return if key.nil?
      norm = normalize_key(key)
      orig_key = @names[norm] || key.to_s
      @names[norm] = orig_key

      @multi_values[norm] ||= []
      @multi_values[norm] << value

      @headers[orig_key] = value
    end

    def get_all(key)
      return [] if key.nil?
      @multi_values[normalize_key(key)] || []
    end

    def key?(key)
      return false if key.nil?
      @names.key?(normalize_key(key))
    end
    alias has_key? key?
    alias include? key?

    def each(&block)
      @headers.each(&block)
    end

    def keys
      @headers.keys
    end

    def values
      @headers.values
    end

    def to_h
      @headers.dup
    end
    alias to_hash to_h

    def inspect
      "#<#{self.class.name} #{@headers.inspect}>"
    end

    def to_s
      @headers.to_s
    end

    private

    def normalize_key(key)
      key.to_s.downcase.tr('_', '-')
    end
  end
end
