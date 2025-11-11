# frozen_string_literal: true

module FerrumMCP
  module Tools
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
              enum: %w[load domcontentloaded networkidle],
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
  end
end
