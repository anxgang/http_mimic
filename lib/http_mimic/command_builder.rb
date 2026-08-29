# frozen_string_literal: true

require 'uri'
require 'json'

module HttpMimic
  class CommandBuilder
    COMMON_SEARCH_PATHS = [
      '/opt/homebrew/bin',
      '/usr/local/bin',
      '/usr/bin',
      '/bin',
      File.expand_path('~/.local/bin')
    ].freeze

    TARGET_BINARY_MAP = {
      # Chrome Desktop
      'chrome'            => %w[curl_chrome131 curl_chrome124 curl_chrome120 curl_chrome116 curl_chrome110 curl-impersonate-chrome curl_chrome curl-impersonate],
      'chrome116'         => %w[curl_chrome116 curl-impersonate-chrome curl_chrome curl-impersonate],
      'chrome120'         => %w[curl_chrome120 curl-impersonate-chrome curl_chrome curl-impersonate],
      'chrome123'         => %w[curl_chrome123 curl-impersonate-chrome curl_chrome curl-impersonate],
      'chrome124'         => %w[curl_chrome124 curl-impersonate-chrome curl_chrome curl-impersonate],
      'chrome131'         => %w[curl_chrome131 curl-impersonate-chrome curl_chrome curl-impersonate],
      'chrome133a'        => %w[curl_chrome133a curl-impersonate-chrome curl_chrome curl-impersonate],
      'chrome136'         => %w[curl_chrome136 curl-impersonate-chrome curl_chrome curl-impersonate],
      'chrome142'         => %w[curl_chrome142 curl-impersonate-chrome curl_chrome curl-impersonate],
      'chrome145'         => %w[curl_chrome145 curl_chrome146 curl_chrome150 curl_chrome131 curl-impersonate],
      'chrome146'         => %w[curl_chrome146 curl_chrome150 curl_chrome145 curl_chrome131 curl-impersonate],
      'chrome150'         => %w[curl_chrome150 curl_chrome146 curl_chrome145 curl_chrome131 curl-impersonate],
      'chrome110'         => %w[curl_chrome110 curl-impersonate-chrome curl_chrome curl-impersonate],
      'chrome107'         => %w[curl_chrome107 curl-impersonate-chrome curl_chrome curl-impersonate],
      'chrome104'         => %w[curl_chrome104 curl-impersonate-chrome curl_chrome curl-impersonate],
      'chrome101'         => %w[curl_chrome101 curl-impersonate-chrome curl_chrome curl-impersonate],
      'chrome100'         => %w[curl_chrome100 curl-impersonate-chrome curl_chrome curl-impersonate],
      'chrome99'          => %w[curl_chrome99 curl-impersonate-chrome curl_chrome curl-impersonate],

      # Mobile / Android
      'chrome131_android' => %w[curl_chrome131_android curl_chrome131 curl-impersonate-chrome curl-impersonate],
      'chrome99_android'  => %w[curl_chrome99_android curl_chrome99 curl-impersonate-chrome curl-impersonate],
      'android'           => %w[curl_chrome131_android curl_safari180_ios curl_chrome99_android curl_chrome131 curl-impersonate],
      'chrome_android'    => %w[curl_chrome131_android curl_chrome99_android curl_chrome131 curl-impersonate],

      # Firefox
      'firefox'           => %w[curl_firefox135 curl_firefox133 curl_ff117 curl_firefox117 curl_ff109 curl-impersonate-ff curl_firefox curl-impersonate],
      'firefox147'        => %w[curl_firefox147 curl_firefox144 curl_firefox135 curl-impersonate-ff curl-impersonate],
      'firefox144'        => %w[curl_firefox144 curl_firefox147 curl_firefox135 curl-impersonate-ff curl-impersonate],
      'firefox135'        => %w[curl_firefox135 curl-impersonate-ff curl_firefox curl-impersonate],
      'firefox133'        => %w[curl_firefox133 curl-impersonate-ff curl_firefox curl-impersonate],
      'firefox117'        => %w[curl_ff117 curl_firefox117 curl-impersonate-ff curl_firefox curl-impersonate],
      'firefox109'        => %w[curl_ff109 curl_firefox109 curl-impersonate-ff curl_firefox curl-impersonate],
      'firefox102'        => %w[curl_ff102 curl_firefox102 curl-impersonate-ff curl_firefox curl-impersonate],
      'firefox98'         => %w[curl_ff98 curl_firefox98 curl-impersonate-ff curl_firefox curl-impersonate],

      # Safari Desktop
      'safari'            => %w[curl_safari180 curl_safari170 curl_safari184 curl_safari260 curl_safari155 curl_safari153 curl-impersonate-safari curl_safari curl-impersonate],
      'safari2601'        => %w[curl_safari2601 curl_safari260 curl_safari180 curl-impersonate-safari curl-impersonate],
      'safari260'         => %w[curl_safari260 curl_safari2601 curl_safari180 curl-impersonate-safari curl-impersonate],
      'safari184'         => %w[curl_safari184 curl_safari180 curl-impersonate-safari curl-impersonate],
      'safari180'         => %w[curl_safari180 curl_safari18_0 curl-impersonate-safari curl_safari curl-impersonate],
      'safari170'         => %w[curl_safari170 curl_safari17_0 curl-impersonate-safari curl_safari curl-impersonate],
      'safari155'         => %w[curl_safari155 curl_safari15_5 curl-impersonate-safari curl_safari curl-impersonate],
      'safari15_5'        => %w[curl_safari155 curl_safari15_5 curl-impersonate-safari curl_safari curl-impersonate],
      'safari153'         => %w[curl_safari153 curl_safari15_3 curl-impersonate-safari curl_safari curl-impersonate],
      'safari15_3'        => %w[curl_safari153 curl_safari15_3 curl-impersonate-safari curl_safari curl-impersonate],

      # Safari iOS / Mobile
      'safari180_ios'     => %w[curl_safari180_ios curl_safari184_ios curl_safari260_ios curl_safari172_ios curl_safari180 curl-impersonate],
      'safari184_ios'     => %w[curl_safari184_ios curl_safari180_ios curl_safari260_ios curl_safari172_ios curl_safari180 curl-impersonate],
      'safari260_ios'     => %w[curl_safari260_ios curl_safari184_ios curl_safari180_ios curl_safari172_ios curl_safari180 curl-impersonate],
      'safari172_ios'     => %w[curl_safari172_ios curl_safari180_ios curl_safari184_ios curl_safari180 curl-impersonate],
      'ios'               => %w[curl_safari180_ios curl_safari184_ios curl_safari260_ios curl_safari172_ios curl_safari180 curl-impersonate],
      'safari_ios'        => %w[curl_safari180_ios curl_safari184_ios curl_safari260_ios curl_safari172_ios curl_safari180 curl-impersonate],
      'mobile'            => %w[curl_safari180_ios curl_chrome131_android curl_safari184_ios curl_safari260_ios curl-impersonate],

      # Edge & Tor
      'edge'              => %w[curl_edge101 curl_edge99 curl-impersonate-edge curl_edge curl-impersonate],
      'edge101'           => %w[curl_edge101 curl-impersonate-edge curl_edge curl-impersonate],
      'edge99'            => %w[curl_edge99 curl-impersonate-edge curl_edge curl-impersonate],
      'tor'               => %w[curl_tor145 curl_tor curl-impersonate],
      'tor145'            => %w[curl_tor145 curl_tor curl-impersonate]
    }.freeze

    attr_reader :method, :url, :options, :config

    def initialize(method, url, options = {}, config = nil)
      @method  = method.to_s.upcase
      @url     = url.to_s
      @options = options.dup
      @config  = config || HttpMimic.configuration
    end

    def build
      binary = resolve_binary
      args = []
      stdin_data = nil

      # Base flags: silent mode, include HTTP headers
      args << '-s'
      args << '-i'

      # HTTP Method
      if @method == 'HEAD'
        args << '-I'
      else
        args << '-X' << @method
      end

      # Process URL and query parameters
      final_url = build_url

      # Redirects
      follow = options.fetch(:follow_redirects, config.follow_redirects)
      if follow
        args << '-L'
        max_redirs = options[:max_redirects] || config.max_redirects
        args << '--max-redirs' << max_redirs.to_s if max_redirs
      end

      # Timeouts
      timeout = options[:timeout] || options[:read_timeout] || config.default_timeout
      args << '--max-time' << timeout.to_s if timeout

      connect_timeout = options[:connect_timeout] || config.default_connect_timeout
      args << '--connect-timeout' << connect_timeout.to_s if connect_timeout

      # SSL / Insecure
      insecure = options[:insecure] || (options.key?(:verify_ssl) && !options[:verify_ssl])
      args << '-k' if insecure
      args << '--cacert' << options[:ssl_ca_file] if options[:ssl_ca_file]
      args << '--cert' << options[:ssl_cert] if options[:ssl_cert]
      args << '--key' << options[:ssl_key] if options[:ssl_key]

      # Proxy
      if options[:proxy]
        args << '-x' << options[:proxy].to_s
        if options[:proxy_auth]
          u = options[:proxy_auth][:username]
          p = options[:proxy_auth][:password]
          args << '--proxy-user' << "#{u}:#{p}"
        end
      end

      # Basic / Digest Auth
      if options[:basic_auth]
        u = options[:basic_auth][:username]
        p = options[:basic_auth][:password]
        args << '-u' << "#{u}:#{p}"
      elsif options[:digest_auth]
        u = options[:digest_auth][:username]
        p = options[:digest_auth][:password]
        args << '--digest' << '-u' << "#{u}:#{p}"
      end

      # Headers
      headers_to_send = Headers.new(options[:headers] || {})
      
      # Bearer Token
      if options[:bearer_token]
        headers_to_send['Authorization'] = "Bearer #{options[:bearer_token]}"
      end

      # Body / JSON / Form
      if options.key?(:json)
        headers_to_send['Content-Type'] ||= 'application/json'
        headers_to_send['Accept'] ||= 'application/json'
        
        json_data = options[:json]
        stdin_data = json_data.is_a?(String) ? json_data : JSON.dump(json_data)
        args << '-d' << '@-'
      elsif options.key?(:body)
        body_data = options[:body]
        if body_data.is_a?(Hash)
          headers_to_send['Content-Type'] ||= 'application/x-www-form-urlencoded'
          stdin_data = encode_params(body_data)
        else
          stdin_data = body_data.to_s
        end
        args << '-d' << '@-'
      elsif options[:form_data] || options[:form] || options[:multipart]
        form_hash = options[:form_data] || options[:form] || options[:multipart]
        if form_hash.is_a?(Hash)
          form_hash.each do |k, v|
            args << '-F' << "#{k}=#{v}"
          end
        end
      end

      # Cookies
      if options[:cookies]
        args << '-b' << Cookies.format(options[:cookies])
      elsif options[:cookie_file]
        args << '-b' << options[:cookie_file].to_s
      end

      if options[:cookie_jar]
        args << '-c' << options[:cookie_jar].to_s
      end

      # User-Agent
      if options[:user_agent]
        args << '-A' << options[:user_agent].to_s
      end

      # Profile-specific headers & HTTP version defaults (for server/curl mode)
      if options[:profile] == :curl
        args << '--http1.1' unless (options[:curl_options] || []).to_s.include?('--http')
        headers_to_send['User-Agent'] ||= (options[:user_agent] || 'Ruby')
        headers_to_send['Accept'] ||= '*/*'
        headers_to_send['Accept-Encoding'] ||= 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3'
        headers_to_send['Connection'] ||= 'close'
      end

      # Append headers
      headers_to_send.each do |k, v|
        if v.is_a?(Array)
          v.each { |item| args << '-H' << "#{k}: #{item}" }
        else
          args << '-H' << "#{k}: #{v}"
        end
      end

      # Custom extra curl options
      if options[:curl_options]
        extra_opts = options[:curl_options]
        extra_opts = extra_opts.split if extra_opts.is_a?(String)
        args.concat(Array(extra_opts))
      end

      # Append final URL
      args << final_url

      [binary, args, stdin_data, final_url]
    end

    def resolve_binary
      # 0. If profile is explicitly set to :curl, use system curl
      if options[:profile] == :curl
        curl_path = find_executable('curl') || 'curl'
        return curl_path if executable?(curl_path)
        raise BinaryNotFoundError, "System curl executable was not found."
      end

      # 1. Use explicit binary_path from options or config if provided
      explicit = options[:binary] || config.binary_path
      if explicit
        path = find_executable(explicit) || explicit
        return path if executable?(path)
        raise BinaryNotFoundError, "Specified executable does not exist or is not executable: #{explicit}"
      end

      target = case options[:profile]
               when :android
                 (options[:android_impersonate] || 'chrome131_android').to_s.downcase
               when :ios
                 (options[:ios_impersonate] || 'safari260_ios').to_s.downcase
               when :mobile
                 (options[:mobile_impersonate] || 'chrome131_android').to_s.downcase
               else
                 (options[:impersonate] || config.default_impersonate).to_s.downcase
               end
      candidate_names = TARGET_BINARY_MAP[target] || ["curl_#{target}", target]

      # 2. Check local installation directory (~/.http_mimic/bin)
      if binary = find_in_download_dir(candidate_names)
        return binary
      end

      # 3. Auto-download driver if not installed locally and auto_download is enabled
      if config.auto_download
        begin
          Downloader.download!(version: config.driver_version, install_dir: config.install_dir)
          if binary = find_in_download_dir(candidate_names)
            return binary
          end
        rescue StandardError => e
          if config.logger
            config.logger.warn("[HttpMimic] Failed to auto-download curl-impersonate: #{e.message}")
          elsif config.debug
            puts "[HttpMimic WARN] Failed to auto-download curl-impersonate: #{e.message}"
          end
        end
      end

      # 4. Search system PATH for target impersonate binary
      candidate_names.each do |name|
        path = find_executable(name)
        return path if path
      end

      # 5. Fall back to general curl-impersonate binary if specific version is not found
      %w[curl-impersonate-chrome curl-impersonate-ff curl-impersonate].each do |name|
        path = find_executable(name)
        return path if path
      end

      # 6. Fallback to system curl if enabled
      if config.fallback_to_curl
        curl_path = find_executable('curl') || 'curl'
        return curl_path if executable?(curl_path)
      end

      raise BinaryNotFoundError, "Could not find a curl-impersonate binary for '#{target}', and no fallback curl executable was found."
    end

    private

    def find_in_download_dir(candidates)
      target_dir = File.expand_path(config.install_dir)
      return nil unless Dir.exist?(target_dir)

      candidates.each do |name|
        path = File.join(target_dir, name)
        return path if executable?(path)
      end

      # Try generic curl-impersonate binary
      gen_path = File.join(target_dir, 'curl-impersonate')
      return gen_path if executable?(gen_path)

      nil
    end

    def build_url
      base = options[:base_uri] || ''
      full = if @url.start_with?('http://', 'https://')
               @url
             elsif base.empty?
               @url
             else
               URI.join(base.end_with?('/') ? base : "#{base}/", @url.sub(%r{^/}, '')).to_s
             end

      query_params = options[:query] || options[:params]
      if query_params && !query_params.empty?
        uri = URI.parse(full)
        existing_query = uri.query
        new_query = encode_params(query_params)
        uri.query = existing_query && !existing_query.empty? ? "#{existing_query}&#{new_query}" : new_query
        uri.to_s
      else
        full
      end
    rescue URI::InvalidURIError
      full
    end

    def encode_params(params)
      if defined?(Rack::Utils) && Rack::Utils.respond_to?(:build_nested_query)
        Rack::Utils.build_nested_query(params)
      else
        URI.encode_www_form(flatten_params(params))
      end
    end

    def flatten_params(params, parent_key = nil)
      params.flat_map do |k, v|
        full_key = parent_key ? "#{parent_key}[#{k}]" : k.to_s
        if v.is_a?(Hash)
          flatten_params(v, full_key)
        elsif v.is_a?(Array)
          v.map { |item| ["#{full_key}[]", item] }
        else
          [[full_key, v]]
        end
      end
    end

    def find_executable(name)
      return name if name.include?(File::SEPARATOR) && executable?(name)

      # Search in system PATH
      paths = ENV['PATH'].to_s.split(File::PATH_SEPARATOR) + COMMON_SEARCH_PATHS
      paths.uniq.each do |dir|
        next unless dir && Dir.exist?(dir)
        full_path = File.join(dir, name)
        return full_path if executable?(full_path)
      end

      nil
    end

    def executable?(path)
      File.file?(path) && File.executable?(path)
    rescue StandardError
      false
    end
  end
end
