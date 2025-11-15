# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to get page title
    class GetTitleTool < BaseTool
      def self.tool_name
        'get_title'
      end

      def self.description
        'Get the title of the current page'
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
        logger.info 'Getting page title'

        success_response(
          title: browser.title,
          url: browser.url
        )
      rescue StandardError => e
        logger.error "Get title failed: #{e.message}"
        error_response("Failed to get title: #{e.message}")
      end
    end
  end
end
