# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Evaluate JavaScript and return the result
    class EvaluateJSTool < BaseTool
      tool_name 'evaluate_js'
      description 'Evaluate a JavaScript expression in the page and return its (JSON-serializable) result'

      param :expression, type: :string, required: true, description: 'JavaScript expression to evaluate'

      def perform(params)
        ensure_browser_active
        logger.info 'Evaluating JavaScript'
        result = page.evaluate(params[:expression].to_s)

        success_response(result: result)
      rescue StandardError => e
        logger.error "Evaluate JS failed: #{e.message}"
        error_response("Failed to evaluate JS: #{e.message}")
      end
    end
  end
end
