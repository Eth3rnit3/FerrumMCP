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
            },
            session_id: {
              type: 'string',
              description: 'Session ID to use for this operation'
            }
          },
          required: ['session_id']
        }
      end

      def execute(params)
        ensure_browser_active
        timeout = param(params, :timeout) || 30
        wait_until = param(params, :wait_until) || 'load'

        logger.info "Waiting for navigation (#{wait_until})"

        start_time = Time.now
        deadline = Time.now + timeout

        # Store initial document to detect navigation even if URL doesn't change
        # This handles SPAs and same-URL form submissions
        begin
          initial_doc = browser.evaluate('document')
        rescue Ferrum::JavaScriptError => e
          logger.warn "Could not capture initial document: #{e.message}"
          initial_doc = nil
        end

        logger.debug "Waiting for navigation from: #{browser.url}"

        # Wait for navigation by monitoring for document changes
        navigated = false

        loop do
          begin
            current_doc = browser.evaluate('document')
            if initial_doc && current_doc != initial_doc
              navigated = true
              logger.debug 'Document changed, navigation detected'
              break
            end
          rescue Ferrum::JavaScriptError
            # Document might be in transitional state during navigation
            navigated = true
            logger.debug 'Document unavailable, navigation in progress'
            break
          end

          raise ToolError, 'Timeout waiting for navigation' if Time.now > deadline

          sleep 0.1
        end

        if navigated
          # Wait for the new page to be ready based on wait_until parameter
          case wait_until
          when 'load', 'domcontentloaded'
            browser.network.wait_for_idle(timeout: [timeout - (Time.now - start_time), 5].max)
          when 'networkidle'
            browser.network.wait_for_idle(duration: 0.5, timeout: [timeout - (Time.now - start_time), 5].max)
          end
        end

        elapsed = (Time.now - start_time).round(2)

        success_response(
          url: browser.url,
          title: browser.title,
          elapsed_seconds: elapsed
        )
      rescue Ferrum::TimeoutError => e
        logger.error "Navigation timeout: #{e.message}"
        error_response("Navigation timed out: #{e.message}")
      rescue StandardError => e
        logger.error "Wait for navigation failed: #{e.message}"
        error_response("Failed to wait for navigation: #{e.message}")
      end
    end
  end
end
