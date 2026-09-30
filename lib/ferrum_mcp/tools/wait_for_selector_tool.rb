# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Wait for an element to reach a state
    class WaitForSelectorTool < BaseTool
      tool_name 'wait_for_selector'
      description 'Wait until an element matching the selector is visible, hidden, attached to or detached from the DOM'

      param :selector, type: :string, required: true, description: 'CSS selector, XPath (xpath: prefix) or snapshot ref'
      param :state, type: :string, default: 'visible', enum: %w[visible hidden attached detached],
                    description: 'State to wait for (default: visible)'
      param :timeout, type: :number, default: 10, description: 'Maximum seconds to wait (default: 10)'

      PRESENT_STATES = %w[visible attached].freeze

      def perform(params)
        ensure_browser_active
        selector = params[:selector]
        state = params[:state]
        timeout = params[:timeout].to_f
        logger.info "Waiting for #{selector} to be #{state} (timeout: #{timeout}s)"

        started = monotonic_now
        until state_reached?(selector, state)
          if monotonic_now - started > timeout
            raise ToolError, "Timed out after #{timeout}s waiting for #{selector} to be #{state}"
          end

          sleep POLL_INTERVAL
        end

        success_response(found: PRESENT_STATES.include?(state), state: state, selector: selector,
                         elapsed_ms: ((monotonic_now - started) * 1000).round)
      end

      private

      def state_reached?(selector, state)
        element = safe_match(selector)
        case state
        when 'attached' then !element.nil?
        when 'detached' then element.nil?
        when 'visible' then !element.nil? && element_visible?(element)
        else element.nil? || !element_visible?(element) # hidden
        end
      end

      def safe_match(selector)
        first_match(selector)
      rescue Ferrum::NodeNotFoundError
        nil
      end
    end
  end
end
