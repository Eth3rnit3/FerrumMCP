# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to clear cookies
    class ClearCookiesTool < BaseTool
      def self.tool_name
        'clear_cookies'
      end

      def self.description
        'Clear all cookies or cookies for a specific domain'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            domain: {
              type: 'string',
              description: 'Optional: Clear cookies only for this domain'
            },
            session_id: {
              type: 'string',
              description: 'Session ID to use for this operation'
            }
          },
          required: ['session_id']
        }
      end

      def execute(params)
        ensure_browser_active
        domain = params['domain'] || params[:domain]

        if domain
          logger.info "Clearing cookies for: #{domain}"
          # cookies.all returns a hash where keys are cookie names and values can be Cookie objects or strings
          all_cookies = browser.cookies.all
          cookies_to_remove = all_cookies.select do |_name, cookie|
            cookie_str = cookie.is_a?(String) ? cookie : cookie.to_s
            cookie_str&.match(/Domain=([^;]+)/i) &&
              Regexp.last_match(1).include?(domain)
          end
          # Remove each cookie by name with domain
          cookies_to_remove.each do |cookie_name, cookie|
            # Extract domain from cookie string
            cookie_str = cookie.is_a?(String) ? cookie : cookie.to_s
            if cookie_str =~ /Domain=([^;]+)/i
              cookie_domain = Regexp.last_match(1).strip
              browser.cookies.remove(name: cookie_name, domain: cookie_domain)
            end
          end
          success_response(message: "Cleared #{cookies_to_remove.length} cookies for #{domain}")
        else
          logger.info 'Clearing all cookies'
          browser.cookies.clear
          success_response(message: 'All cookies cleared')
        end
      rescue StandardError => e
        logger.error "Clear cookies failed: #{e.message}"
        error_response("Failed to clear cookies: #{e.message}")
      end
    end
  end
end
