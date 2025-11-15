# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to get current URL
    class GetURLTool < BaseTool
      def self.tool_name
        'get_url'
      end

      def self.description
        'Get the current URL of the page'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            session_id: {
              type: 'string',
              description: 'Session ID to use for this operation'
            }
          },
          required: ['session_id']
        }
      end

      def execute(_params)
        ensure_browser_active

        logger.info 'Getting current URL'
        success_response(url: browser.url)
      rescue StandardError => e
        logger.error "Get URL failed: #{e.message}"
        error_response("Failed to get URL: #{e.message}")
      end
    end
  end
end
