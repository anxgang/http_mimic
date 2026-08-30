# frozen_string_literal: true

module HttpMimic
  module SpaDetector
    # Framework mount points that indicate an unhydrated SPA client shell
    EMPTY_MOUNT_REGEX = %r{
      <div[^>]+id=["'](?:root|app|__next|__nuxt|svelte)["'][^>]*>\s*</div>|
      <app-root[^>]*>\s*</app-root>|
      <div[^>]+id=["']app["'][^>]*>\s*<!--\s*(?:app-content)?\s*-->\s*</div>
    }ix

    # Noscript patterns requiring JavaScript execution
    NOSCRIPT_JS_REQUIRED_REGEX = %r{
      <noscript[^>]*>[\s\S]*?(?:enable\s+javascript|javascript\s+is\s+required|need\s+to\s+enable\s+javascript|requires\s+javascript)[\s\S]*?</noscript>
    }ix

    # Google Search Guard dynamic SPA shell indicators
    GOOGLE_SHELL_REGEX = %r{
      (?:/httpservice/retry/enablejs|SG_REL|emsg=SG_REL|knitsail)
    }ix

    class << self
      # Returns true if the HTTP response represents an unhydrated Single Page Application (SPA) shell
      #
      # @param response [HttpMimic::Response]
      # @return [Boolean]
      def spa?(response)
        return false unless response && response.success?
        return false if response.respond_to?(:binary?) && response.binary?

        content_type = response.headers['content-type'].to_s.downcase
        return false unless content_type.empty? || content_type.include?('text/html') || content_type.include?('application/xhtml')

        body = response.body.to_s
        return false if body.strip.empty?

        # 1. Google Dynamic SERP / Search Guard JS Shell
        if google_serp_shell?(body)
          return true
        end

        # 2. Modern SPA framework empty mount points (React, Vue, Angular, Next, Nuxt, Svelte)
        if empty_mount_point?(body)
          return true
        end

        # 3. Noscript requirement message
        if noscript_js_required?(body)
          return true
        end

        # 4. Small body with multiple scripts and virtually no visible text
        if low_text_js_heavy_shell?(body)
          return true
        end

        false
      end

      def empty_mount_point?(body)
        body.match?(EMPTY_MOUNT_REGEX)
      end

      def noscript_js_required?(body)
        body.match?(NOSCRIPT_JS_REQUIRED_REGEX)
      end

      def google_serp_shell?(body)
        return false unless body.match?(GOOGLE_SHELL_REGEX)

        # If it has the Google shell indicators AND lacks rendered organic result elements
        !body.include?('<h3 class=') && !body.include?('id="search"') && !body.include?('id="rso"')
      end

      def low_text_js_heavy_shell?(body)
        return false if body.length > 25_000 # Larger HTML files typically have SSR content

        # Check if there are script tags
        script_count = body.scan(/<script/i).size
        return false if script_count.zero?

        # Strip all HTML tags, scripts, and styles to get raw visible text length
        visible_text = body
                       .gsub(/<script[\s\S]*?<\/script>/i, '')
                       .gsub(/<style[\s\S]*?<\/style>/i, '')
                       .gsub(/<[^>]+>/, ' ')
                       .gsub(/\s+/, ' ')
                       .strip

        # If visible text is virtually nonexistent but page has multiple scripts
        visible_text.length < 80 && script_count >= 2
      end
    end
  end
end
