# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Wait for text to appear
    class WaitForTextTool < BaseTool
      tool_name 'wait_for_text'
      description 'Wait until the given text is visible on the page (optionally inside a specific element)'

      param :text, type: :string, required: true, description: 'Text to wait for'
      param :selector, type: :string, description: 'Optional: CSS selector of the element to search in (default: body)'
      param :exact, type: :boolean, default: false, description: 'Match the whole text exactly (default: substring)'
      param :timeout, type: :number, default: 10, description: 'Maximum seconds to wait (default: 10)'

      def perform(params)
        ensure_browser_active
        text = params[:text].to_s
        selector = params[:selector]
        timeout = params[:timeout].to_f
        logger.info "Waiting for text #{text.inspect}#{" in #{selector}" if selector} (timeout: #{timeout}s)"

        started = monotonic_now
        until text_present?(text, selector, params[:exact])
          if monotonic_now - started > timeout
            raise ToolError,
                  "Timed out after #{timeout}s waiting for text #{text.inspect}"
          end

          sleep POLL_INTERVAL
        end

        success_response(found: true, text: text, selector: selector,
                         elapsed_ms: ((monotonic_now - started) * 1000).round)
      end

      private

      def text_present?(text, selector, exact)
        page.evaluate(<<~JS, selector, text, exact ? true : false)
          (function(selector, text, exact) {
            const root = selector ? document.querySelector(selector) : document.body;
            if (!root) return false;
            const content = (root.innerText || root.textContent || '');
            return exact ? content.trim() === text : content.includes(text);
          })(arguments[0], arguments[1], arguments[2])
        JS
      end
    end
  end
end
