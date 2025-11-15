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
        domain = param(params, :domain)

        logger.info "Getting cookies#{" for #{domain}" if domain}"
        all_cookies = browser.cookies.all

        # Convert cookies to structured format
        cookies_array = []

        all_cookies.each do |name, cookie|
          # Get structured cookie data if available
          cookie_data = if cookie.respond_to?(:to_h)
                          cookie.to_h
                        elsif cookie.is_a?(Hash)
                          cookie
                        else
                          # Fallback to basic format
                          { name: name, value: cookie.to_s }
                        end

          # Ensure name is set
          cookie_data[:name] ||= name

          # Filter by domain if specified
          cookies_array << cookie_data if domain.nil? || cookie_data[:domain]&.include?(domain)
        end

        success_response(
          cookies: cookies_array,
          count: cookies_array.length
        )
      rescue StandardError => e
        logger.error "Get cookies failed: #{e.message}"
        error_response("Failed to get cookies: #{e.message}")
      end
    end
  end
end
