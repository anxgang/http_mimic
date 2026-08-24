# frozen_string_literal: true

require 'rbconfig'
require 'net/http'
require 'uri'
require 'fileutils'
require 'zlib'
require 'rubygems/package'
require 'open3'

module HttpMimic
  class Downloader
    DEFAULT_GITHUB_REPO = 'lexiforest/curl-impersonate'
    DEFAULT_VERSION     = 'v2.1.1'

    class DownloadError < HttpMimic::Error; end
    class UnsupportedPlatformError < HttpMimic::Error; end

    class << self
      def download!(version: nil, install_dir: nil, repo: nil, force: false)
        target_version = normalize_version(version || HttpMimic.configuration.driver_version || DEFAULT_VERSION)
        target_dir     = File.expand_path(install_dir || HttpMimic.configuration.install_dir)
        target_repo    = repo || HttpMimic.configuration.github_repo || DEFAULT_GITHUB_REPO

        FileUtils.mkdir_p(target_dir)

        # Check if the target version is already installed and intact
        if !force && installed?(version: target_version, install_dir: target_dir)
          log_info("curl-impersonate #{target_version} is already installed in #{target_dir}")
          return target_dir
        end

        slug = platform_slug
        asset_name = "curl-impersonate-#{target_version}.#{slug}.tar.gz"
        download_url = "https://github.com/#{target_repo}/releases/download/#{target_version}/#{asset_name}"

        log_info("Downloading curl-impersonate (#{target_version}) [#{asset_name}]...")

        archive_data = fetch_binary(download_url)

        log_info("Extracting archive to #{target_dir}...")
        extract_tar_gz(archive_data, target_dir)

        # Write version marker file
        File.write(version_file_path(target_dir), target_version)

        log_info("curl-impersonate #{target_version} installation complete!")
        target_dir
      end

      def installed?(version: nil, install_dir: nil)
        target_dir = File.expand_path(install_dir || HttpMimic.configuration.install_dir)
        core_binary = File.join(target_dir, binary_name_for_platform('curl-impersonate'))
        return false unless File.file?(core_binary) && File.executable?(core_binary)

        if version
          target_version = normalize_version(version)
          v_file = version_file_path(target_dir)
          return false unless File.file?(v_file)
          return File.read(v_file).strip == target_version
        end

        true
      end

      def binary_path(name, install_dir: nil)
        target_dir = File.expand_path(install_dir || HttpMimic.configuration.install_dir)
        candidate = File.join(target_dir, binary_name_for_platform(name))
        return candidate if File.file?(candidate) && File.executable?(candidate)

        nil
      end

      def available_binaries(install_dir: nil)
        target_dir = File.expand_path(install_dir || HttpMimic.configuration.install_dir)
        return [] unless Dir.exist?(target_dir)

        Dir.glob(File.join(target_dir, '*')).select do |file|
          File.file?(file) && File.executable?(file)
        end.map { |f| File.basename(f) }
      end

      def platform_slug
        os  = host_os
        cpu = host_cpu

        case os
        when :macos
          case cpu
          when :arm64 then 'arm64-macos'
          when :x86_64 then 'x86_64-macos'
          else
            raise UnsupportedPlatformError, "Unsupported macOS CPU architecture: #{cpu}"
          end
        when :linux
          libc = linux_libc
          case cpu
          when :x86_64
            libc == :musl ? 'x86_64-linux-musl' : 'x86_64-linux-gnu'
          when :aarch64, :arm64
            libc == :musl ? 'aarch64-linux-musl' : 'aarch64-linux-gnu'
          when :i386, :i686
            'i386-linux-gnu'
          when :arm
            'arm-linux-gnueabihf'
          when :riscv64
            'riscv64-linux-gnu'
          when :loongarch64
            'loongarch64-linux-gnu'
          else
            raise UnsupportedPlatformError, "Unsupported Linux CPU architecture: #{cpu}"
          end
        when :windows
          case cpu
          when :x86_64 then 'x86_64-win32'
          when :arm64 then 'arm64-win32'
          when :i386, :i686 then 'i686-win32'
          else
            raise UnsupportedPlatformError, "Unsupported Windows CPU architecture: #{cpu}"
          end
        when :freebsd
          case cpu
          when :x86_64 then 'x86_64-freebsd'
          when :arm64, :aarch64 then 'aarch64-freebsd'
          else
            raise UnsupportedPlatformError, "Unsupported FreeBSD CPU architecture: #{cpu}"
          end
        else
          raise UnsupportedPlatformError, "Unsupported operating system: #{RbConfig::CONFIG['host_os']}"
        end
      end

      private

      def host_os
        os_str = RbConfig::CONFIG['host_os'].downcase
        case os_str
        when /darwin|mac os/
          :macos
        when /linux/
          :linux
        when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
          :windows
        when /freebsd/
          :freebsd
        else
          :unknown
        end
      end

      def host_cpu
        cpu_str = RbConfig::CONFIG['host_cpu'].downcase
        case cpu_str
        when /arm64|aarch64/
          host_os == :macos || host_os == :windows ? :arm64 : :aarch64
        when /x86_64|amd64|x64/
          :x86_64
        when /i[3-6]86|x86/
          :i386
        when /arm/
          :arm
        when /riscv64/
          :riscv64
        when /loongarch64/
          :loongarch64
        else
          cpu_str.to_sym
        end
      end

      def linux_libc
        if File.exist?('/etc/alpine-release') || `ldd --version 2>&1` =~ /musl/i
          :musl
        else
          :gnu
        end
      rescue StandardError
        :gnu
      end

      def binary_name_for_platform(name)
        host_os == :windows ? "#{name}.exe" : name
      end

      def normalize_version(ver)
        v = ver.to_s.strip
        v.start_with?('v') ? v : "v#{v}"
      end

      def version_file_path(dir)
        File.join(dir, '.version')
      end

      def fetch_binary(url, limit = 5)
        raise DownloadError, "Download failed: too many redirects (#{url})" if limit <= 0

        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        http.read_timeout = 60
        http.open_timeout = 30

        req = Net::HTTP::Get.new(uri.request_uri)
        req['User-Agent'] = "Ruby-HttpMimic/#{HttpMimic::VERSION} (#{RUBY_PLATFORM})"

        res = http.request(req)

        case res
        when Net::HTTPSuccess
          res.body
        when Net::HTTPRedirection
          location = res['location']
          fetch_binary(location, limit - 1)
        else
          raise DownloadError, "Download failed with HTTP status #{res.code}: #{url}"
        end
      rescue StandardError => e
        raise DownloadError, "Failed to download curl-impersonate release: #{e.message}"
      end

      def extract_tar_gz(data, dest_dir)
        # 1. Try system tar command first
        begin
          tmp_tar = File.join(dest_dir, ".temp_download_#{Process.pid}.tar.gz")
          File.binwrite(tmp_tar, data)
          
          _stdout, _stderr, status = Open3.capture3('tar', '-xzf', tmp_tar, '-C', dest_dir)
          FileUtils.rm_f(tmp_tar)

          if status && status.success?
            chmod_all_binaries(dest_dir)
            return
          end
        rescue StandardError => e
          log_info("System tar command failed (#{e.message}), falling back to Ruby extraction...")
        end

        # 2. Pure Ruby tar.gz extraction fallback
        gz = Zlib::GzipReader.new(StringIO.new(data))
        tar = Gem::Package::TarReader.new(gz)

        tar.each do |entry|
          target_path = File.join(dest_dir, entry.full_name)
          if entry.directory?
            FileUtils.mkdir_p(target_path)
          elsif entry.file?
            FileUtils.mkdir_p(File.dirname(target_path))
            File.binwrite(target_path, entry.read)
            File.chmod(0755, target_path)
          end
        end
        tar.close
        gz.close
        chmod_all_binaries(dest_dir)
      end

      def chmod_all_binaries(dir)
        Dir.glob(File.join(dir, '*')).each do |f|
          File.chmod(0755, f) if File.file?(f)
        end
      end

      def log_info(msg)
        if HttpMimic.configuration.logger
          HttpMimic.configuration.logger.info("[HttpMimic::Downloader] #{msg}")
        elsif HttpMimic.configuration.debug
          puts "[HttpMimic::Downloader] #{msg}"
        end
      end
    end
  end
end
