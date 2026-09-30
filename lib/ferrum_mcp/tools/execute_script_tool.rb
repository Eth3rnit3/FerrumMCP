# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Execute JavaScript for side effects
    class ExecuteScriptTool < BaseTool
      tool_name 'execute_script'
      description 'Execute JavaScript code in the page for its side effects (use evaluate_js to get a value back)'

      param :script, type: :string, required: true, description: 'JavaScript code to execute'

      def perform(params)
        ensure_browser_active
        logger.info 'Executing JavaScript'
        page.execute(params[:script].to_s)

        success_response(message: 'Script executed successfully')
      end
    end
  end
end
