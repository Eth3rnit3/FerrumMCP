# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to wait for an element to appear
    class WaitForElementTool < BaseTool
      def self.tool_name
        'wait_for_element'
      end

      def self.description
        'Wait for an element to appear on the page'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            selector: {
              type: 'string',
              description: 'CSS selector of the element to wait for'
            },
            timeout: {
              type: 'number',
              description: 'Maximum seconds to wait (default: 30)',
              default: 30
            },
            state: {
              type: 'string',
              enum: %w[visible hidden exists],
              description: 'Wait for element to be visible, hidden, or just exist (default: visible)',
              default: 'visible'
            }
          },
          required: ['selector']
        }
      end

      def execute(params)
        ensure_browser_active
        selector = params['selector'] || params[:selector]
        timeout = params['timeout'] || params[:timeout] || 30
        state = params['state'] || params[:state] || 'visible'

        logger.info "Waiting for element (#{state}): #{selector}"

        start_time = Time.now

        case state
        when 'visible'
          wait_for_visible(selector, timeout)
        when 'hidden'
          wait_for_hidden(selector, timeout)
        when 'exists'
          wait_for_exists(selector, timeout)
        end

        elapsed = (Time.now - start_time).round(2)

        success_response(
          message: "Element #{state}: #{selector}",
          elapsed_seconds: elapsed
        )
      rescue StandardError => e
        logger.error "Wait for element failed: #{e.message}"
        error_response("Failed to wait for element: #{e.message}")
      end

      private

      def wait_for_visible(selector, timeout)
        deadline = Time.now + timeout

        loop do
          element = browser.at_css(selector)
          return element if element

          raise ToolError, "Timeout waiting for element to be visible: #{selector}" if Time.now > deadline

          sleep 0.5
        end
      end

      def wait_for_exists(selector, timeout)
        deadline = Time.now + timeout

        loop do
          begin
            element = browser.at_css(selector)
            return element if element
          rescue Ferrum::NodeNotFoundError
            # Element doesn't exist yet, continue waiting
          end

          raise ToolError, "Timeout waiting for element to exist: #{selector}" if Time.now > deadline

          sleep 0.5
        end
      end

      def wait_for_hidden(selector, timeout)
        deadline = Time.now + timeout

        loop do
          element = browser.at_css(selector)
          return if element.nil?

          raise ToolError, "Timeout waiting for element to hide: #{selector}" if Time.now > deadline

          sleep 0.5
        end
      end
    end
  end
end
