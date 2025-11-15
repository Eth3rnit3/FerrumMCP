# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to wait for a specific duration
    class WaitTool < BaseTool
      def self.tool_name
        'wait'
      end

      def self.description
        'Wait for a specific number of seconds'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            seconds: {
              type: 'number',
              description: 'Number of seconds to wait',
              minimum: 0.1,
              maximum: 60
            },
            session_id: {
              type: 'string',
              description: 'Session ID to use for this operation'
            }
          },
          required: %w[seconds session_id]
        }
      end

      def execute(params)
        seconds = params['seconds'] || params[:seconds]

        logger.info "Waiting for #{seconds} seconds"
        sleep seconds

        success_response(message: "Waited #{seconds} seconds")
      rescue StandardError => e
        logger.error "Wait failed: #{e.message}"
        error_response("Failed to wait: #{e.message}")
      end
    end
  end
end
