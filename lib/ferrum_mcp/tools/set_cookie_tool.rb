# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to set a cookie
    class SetCookieTool < BaseTool
      def self.tool_name
        'set_cookie'
      end

      def self.description
        'Set a cookie in the browser'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            name: {
              type: 'string',
              description: 'Cookie name'
            },
            value: {
              type: 'string',
              description: 'Cookie value'
            },
            domain: {
              type: 'string',
              description: 'Cookie domain'
            },
            path: {
              type: 'string',
              description: 'Cookie path (default: /)',
              default: '/'
            },
            secure: {
              type: 'boolean',
              description: 'Secure flag (default: false)',
              default: false
            },
            httponly: {
              type: 'boolean',
              description: 'HttpOnly flag (default: false)',
              default: false
            },
            session_id: {
              type: 'string',
              description: 'Session ID to use for this operation'
            }
          },
          required: %w[name value domain session_id]
        }
      end

      def execute(params)
        ensure_browser_active

        cookie = {
          name: params['name'] || params[:name],
          value: params['value'] || params[:value],
          domain: params['domain'] || params[:domain],
          path: params['path'] || params[:path] || '/',
          secure: params['secure'] || params[:secure] || false,
          httpOnly: params['httponly'] || params[:httponly] || false
        }

        logger.info "Setting cookie: #{cookie[:name]}"
        browser.cookies.set(**cookie)

        success_response(message: "Cookie set: #{cookie[:name]}")
      rescue StandardError => e
        logger.error "Set cookie failed: #{e.message}"
        error_response("Failed to set cookie: #{e.message}")
      end
    end
  end
end
