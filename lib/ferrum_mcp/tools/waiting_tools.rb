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
              enum: ['visible', 'hidden', 'exists'],
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
          element = browser.at_css(selector, wait: timeout)
          raise ToolError, "Element not visible: #{selector}" unless element
        when 'hidden'
          wait_for_hidden(selector, timeout)
        when 'exists'
          browser.at_css(selector, wait: timeout)
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

      def wait_for_hidden(selector, timeout)
        deadline = Time.now + timeout

        loop do
          element = browser.at_css(selector, wait: 0.5)
          return if element.nil?

          raise ToolError, "Timeout waiting for element to hide: #{selector}" if Time.now > deadline

          sleep 0.5
        end
      end
    end

    # Tool to wait for page navigation
    class WaitForNavigationTool < BaseTool
      def self.tool_name
        'wait_for_navigation'
      end

      def self.description
        'Wait for page navigation to complete'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            timeout: {
              type: 'number',
              description: 'Maximum seconds to wait (default: 30)',
              default: 30
            },
            wait_until: {
              type: 'string',
              enum: ['load', 'domcontentloaded', 'networkidle'],
              description: 'When to consider navigation complete (default: load)',
              default: 'load'
            }
          }
        }
      end

      def execute(params)
        ensure_browser_active
        timeout = params['timeout'] || params[:timeout] || 30
        wait_until = params['wait_until'] || params[:wait_until] || 'load'

        logger.info "Waiting for navigation (#{wait_until})"

        start_time = Time.now
        current_url = browser.url

        # Wait for URL to change or page to reload
        deadline = Time.now + timeout

        loop do
          new_url = browser.url
          break if new_url != current_url

          raise ToolError, 'Timeout waiting for navigation' if Time.now > deadline

          sleep 0.5
        end

        # Additional wait based on wait_until parameter
        case wait_until
        when 'load', 'domcontentloaded'
          browser.network.wait_for_idle(timeout: timeout)
        when 'networkidle'
          browser.network.wait_for_idle(duration: 0.5, timeout: timeout)
        end

        elapsed = (Time.now - start_time).round(2)

        success_response(
          url: browser.url,
          title: browser.title,
          elapsed_seconds: elapsed
        )
      rescue StandardError => e
        logger.error "Wait for navigation failed: #{e.message}"
        error_response("Failed to wait for navigation: #{e.message}")
      end
    end

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
            }
          },
          required: ['seconds']
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
