# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to execute JavaScript code
    class ExecuteScriptTool < BaseTool
      def self.tool_name
        'execute_script'
      end

      def self.description
        'Execute JavaScript code in the browser context'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            script: {
              type: 'string',
              description: 'JavaScript code to execute'
            },
            session_id: {
              type: 'string',
              description: 'Session ID to use for this operation'
            }
          },
          required: ['script', 'session_id']
        }
      end

      def execute(params)
        ensure_browser_active
        script = param(params, :script)

        logger.info 'Executing JavaScript'
        # Use execute for side effects (doesn't return value)
        # For getting return values, users should use EvaluateJSTool
        browser.execute(script)

        success_response(message: 'Script executed successfully')
      rescue StandardError => e
        logger.error "Execute script failed: #{e.message}"
        error_response("Failed to execute script: #{e.message}")
      end
    end
  end
end
