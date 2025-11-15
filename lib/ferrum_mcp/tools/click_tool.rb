# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to click on an element
    class ClickTool < BaseTool
      def self.tool_name
        'click'
      end

      def self.description
        'Click on an element using a CSS selector or XPath'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            selector: {
              type: 'string',
              description: 'CSS selector or XPath of the element to click (use xpath: prefix for XPath)'
            },
            wait: {
              type: 'number',
              description: 'Seconds to wait for element (default: 5)',
              default: 5
            },
            force: {
              type: 'boolean',
              description: 'Force click even if element is hidden or not visible (default: false)',
              default: false
            }
          },
          required: ['selector']
        }
      end

      def execute(params)
        selector = param(params, :selector)
        wait_time = param(params, :wait) || 5
        force = param(params, :force) || false

        logger.info "Clicking element: #{selector} (force: #{force})"

        # Use retry logic for stale elements
        with_retry do
          element = find_element_robust(selector, wait_time)

          # Scroll element into view before clicking
          element.scroll_into_view if element.respond_to?(:scroll_into_view)

          # Use native Ferrum click
          element.click
        end

        success_response(message: "Clicked on #{selector}")
      rescue Ferrum::NodeNotFoundError, Ferrum::CoordinatesNotFoundError, Ferrum::NodeMovingError => e
        # If native click fails and force is enabled, try with JavaScript
        if force
          logger.warn "Native click failed, retrying with JavaScript: #{e.message}"
          click_with_javascript(selector)
          success_response(message: "Clicked on #{selector} (forced)")
        else
          logger.error "Click failed: #{e.message}"
          error_response("Failed to click: #{e.message}. Try with force: true")
        end
      rescue StandardError => e
        # Handle "Node does not have a layout object" and similar errors
        if e.message.include?('layout object') || e.message.include?('not visible')
          if force
            logger.warn "Element not visible, forcing click with JavaScript: #{e.message}"
            click_with_javascript(selector)
            success_response(message: "Clicked on #{selector} (forced)")
          else
            logger.error "Click failed: #{e.message}"
            error_response("Failed to click: #{e.message}. Try with force: true")
          end
        else
          logger.error "Click failed: #{e.message}"
          error_response("Failed to click: #{e.message}")
        end
      end

      private

      def find_element_robust(selector, timeout)
        deadline = Time.now + timeout

        # Support both CSS and XPath selectors
        if selector.start_with?('xpath:', '//')
          xpath = selector.sub(/^xpath:/, '')
          logger.debug "Using XPath: #{xpath}"

          # Retry XPath search until timeout
          elements = []
          loop do
            elements = browser.xpath(xpath)
            break unless elements.empty?

            raise ToolError, "Element not found with XPath: #{xpath}" if Time.now > deadline

            sleep 0.2
          end

          # Prefer visible element
          element = elements.find { |el| element_visible?(el) } || elements.first
          visibility = element_visible?(element) ? 'visible' : 'first'
          logger.debug "Found #{elements.length} XPath matches, using #{visibility} one"
        else
          # For CSS selectors, use the base find_element with timeout
          element = find_element(selector, timeout: timeout)
        end

        element
      end

      def click_with_javascript(selector) # rubocop:disable Metrics/MethodLength
        logger.info "Using JavaScript click for: #{selector}"

        # Build JavaScript to find and click element, even if hidden
        if selector.start_with?('xpath:', '//')
          xpath = selector.sub(/^xpath:/, '')
          script = <<~JAVASCRIPT
            const xpath = #{xpath.inspect};
            const result = document.evaluate(xpath, document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
            const elements = [];
            for (let i = 0; i < result.snapshotLength; i++) {
              elements.push(result.snapshotItem(i));
            }

            if (elements.length === 0) {
              throw new Error('No element found with XPath: ' + xpath);
            }

            // Find first visible element, or use first element if force clicking
            const visible = elements.find(el => el.offsetWidth > 0 && el.offsetHeight > 0);
            const target = visible || elements[0];

            // For hidden elements, temporarily show them, click, then hide again
            const wasHidden = target.offsetWidth === 0 && target.offsetHeight === 0;
            const originalDisplay = target.style.display;
            const originalVisibility = target.style.visibility;

            if (wasHidden) {
              target.style.display = 'block';
              target.style.visibility = 'visible';
            }

            try {
              target.scrollIntoView({ behavior: 'instant', block: 'center' });
              target.click();
            } finally {
              if (wasHidden) {
                target.style.display = originalDisplay;
                target.style.visibility = originalVisibility;
              }
            }

            return true;
          JAVASCRIPT
        else
          script = <<~JAVASCRIPT
            const elements = Array.from(document.querySelectorAll(#{selector.inspect}));

            if (elements.length === 0) {
              throw new Error('No elements found with selector: #{selector}');
            }

            // Find first visible element, or use first element if force clicking
            const visible = elements.find(el => el.offsetWidth > 0 && el.offsetHeight > 0);
            const target = visible || elements[0];

            // For hidden elements, temporarily show them, click, then hide again
            const wasHidden = target.offsetWidth === 0 && target.offsetHeight === 0;
            const originalDisplay = target.style.display;
            const originalVisibility = target.style.visibility;

            if (wasHidden) {
              target.style.display = 'block';
              target.style.visibility = 'visible';
            }

            try {
              target.scrollIntoView({ behavior: 'instant', block: 'center' });
              target.click();
            } finally {
              if (wasHidden) {
                target.style.display = originalDisplay;
                target.style.visibility = originalVisibility;
              }
            }

            return true;
          JAVASCRIPT
        end

        browser.execute(script)
        logger.debug 'JavaScript click executed successfully'
      end

      def element_visible?(element)
        return false unless element

        # Use property instead of evaluate to avoid "Node does not have a layout object" errors
        offset_width = element.property('offsetWidth')
        offset_height = element.property('offsetHeight')
        offset_width&.positive? && offset_height&.positive?
      rescue StandardError => e
        logger.debug "Cannot check visibility: #{e.message}"
        false
      end
    end
  end
end
