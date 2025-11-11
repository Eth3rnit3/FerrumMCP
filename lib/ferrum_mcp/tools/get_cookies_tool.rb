# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to get cookies
    class GetCookiesTool < BaseTool
      def self.tool_name
        'get_cookies'
      end

      def self.description
        'Get all cookies or cookies for a specific domain'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            domain: {
              type: 'string',
              description: 'Optional: Filter cookies by domain'
            }
          }
        }
      end

      def execute(params)
        ensure_browser_active
        domain = params['domain'] || params[:domain]

        logger.info "Getting cookies#{" for #{domain}" if domain}"
        all_cookies = browser.cookies.all

        # Convert cookies to hash format
        # cookies.all returns a hash where values can be Cookie objects or strings
        cookies_hash = {}
        all_cookies.each do |name, cookie|
          cookie_str = cookie.is_a?(String) ? cookie : cookie.to_s
          cookies_hash[name] = cookie_str
        end

        # Filter by domain if specified
        if domain
          cookies_hash = cookies_hash.select do |_name, cookie_string|
            cookie_string&.match(/Domain=([^;]+)/i) &&
              Regexp.last_match(1).include?(domain)
          end
        end

        success_response(
          cookies: cookies_hash,
          count: cookies_hash.length
        )
      rescue StandardError => e
        logger.error "Get cookies failed: #{e.message}"
        error_response("Failed to get cookies: #{e.message}")
      end
    end
  end
end
