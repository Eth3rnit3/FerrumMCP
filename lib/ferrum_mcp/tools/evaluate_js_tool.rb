# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to evaluate JavaScript
    class EvaluateJSTool < BaseTool
      def self.tool_name
        'evaluate_js'
      end

      def self.description
        'Evaluate JavaScript expression and return the result'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            expression: {
              type: 'string',
              description: 'JavaScript expression to evaluate'
            },
            session_id: {
              type: 'string',
              description: 'Session ID to use for this operation'
            }
          },
          required: ['expression', 'session_id']
        }
      end

      def execute(params)
        ensure_browser_active
        expression = params['expression'] || params[:expression]

        logger.info 'Evaluating JavaScript'
        result = browser.evaluate(expression)

        success_response(result: result)
      rescue StandardError => e
        logger.error "Evaluate JS failed: #{e.message}"
        error_response("Failed to evaluate JS: #{e.message}")
      end
    end
  end
end
