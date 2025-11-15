# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to perform drag and drop operations
    class DragAndDropTool < BaseTool
      def self.tool_name
        'drag_and_drop'
      end

      def self.description
        'Drag an element and drop it onto another element or coordinates'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            source_selector: {
              type: 'string',
              description: 'CSS selector or XPath of the element to drag (use xpath: prefix for XPath)'
            },
            target_selector: {
              type: 'string',
              description: 'CSS selector or XPath of the drop target (optional if using coordinates)'
            },
            target_x: {
              type: 'number',
              description: 'X coordinate to drop at (alternative to target_selector)'
            },
            target_y: {
              type: 'number',
              description: 'Y coordinate to drop at (alternative to target_selector)'
            },
            steps: {
              type: 'number',
              description: 'Number of steps for smooth dragging (default: 10)',
              default: 10
            },
            session_id: {
              type: 'string',
              description: 'Session ID to use for this operation'
            }
          },
          required: %w[source_selector session_id]
        }
      end

      def execute(params) # rubocop:disable Metrics/MethodLength
        source_selector = param(params, :source_selector)
        target_selector = param(params, :target_selector)
        target_x = param(params, :target_x)
        target_y = param(params, :target_y)
        steps = param(params, :steps) || 10

        logger.info "Dragging #{source_selector} to #{target_selector || "(#{target_x}, #{target_y})"}"

        # Wait for source element to exist using find_element
        begin
          find_element_for_drag(source_selector)
        rescue StandardError => e
          raise ToolError, "Source element not found: #{source_selector} - #{e.message}"
        end

        # Get position using JavaScript
        selector_js = source_selector.inspect
        script = <<~JS.strip
          (function() {
            var el = document.querySelector(#{selector_js});
            if (!el) return null;
            var rect = el.getBoundingClientRect();
            var result = {};
            result.x = rect.left + rect.width / 2;
            result.y = rect.top + rect.height / 2;
            return result;
          })()
        JS

        source_pos = browser.evaluate(script)
        raise ToolError, "Failed to get position for: #{source_selector}" if source_pos.nil?

        source_x = source_pos['x']
        source_y = source_pos['y']

        # Determine target coordinates
        if target_selector
          selector_js = target_selector.inspect
          script = <<~JS.strip
            (function() {
              var el = document.querySelector(#{selector_js});
              if (!el) return null;
              var rect = el.getBoundingClientRect();
              var result = {};
              result.x = rect.left + rect.width / 2;
              result.y = rect.top + rect.height / 2;
              return result;
            })()
          JS

          target_pos = browser.evaluate(script)
          raise ToolError, "Target element not found: #{target_selector}" if target_pos.nil?

          final_x = target_pos['x']
          final_y = target_pos['y']
        elsif target_x && target_y
          final_x = target_x
          final_y = target_y
        else
          raise ToolError, 'Either target_selector or both target_x and target_y must be provided'
        end

        # Perform drag and drop using mouse operations
        perform_drag_and_drop(source_x, source_y, final_x, final_y, steps)

        success_response(
          message: "Dragged from (#{source_x.round}, #{source_y.round}) to (#{final_x.round}, #{final_y.round})"
        )
      rescue StandardError => e
        logger.error "Drag and drop failed: #{e.message}"
        error_response("Failed to drag and drop: #{e.message}")
      end

      private

      def find_element_for_drag(selector)
        if selector.start_with?('xpath:', '//')
          xpath = selector.sub(/^xpath:/, '')
          elements = browser.xpath(xpath)
          raise "Element not found with XPath: #{xpath}" if elements.empty?

          elements.first
        else
          find_element(selector)
        end
      end

      def perform_drag_and_drop(from_x, from_y, to_x, to_y, steps)
        mouse = browser.mouse

        # Move to source element
        mouse.move(x: from_x, y: from_y)
        sleep 0.05

        # Press mouse button
        mouse.down
        sleep 0.05 # Small delay to ensure mousedown registers

        # Calculate step size for smooth drag
        step_x = (to_x - from_x) / steps.to_f
        step_y = (to_y - from_y) / steps.to_f

        # Calculate delay per step (aim for ~300ms total drag time)
        delay_per_step = [0.3 / steps, 0.01].max # At least 10ms per step

        # Perform smooth drag
        (1..steps).each do |step|
          current_x = from_x + (step_x * step)
          current_y = from_y + (step_y * step)
          mouse.move(x: current_x, y: current_y)
          sleep delay_per_step
        end

        # Release mouse button
        sleep 0.05 # Small delay before release
        mouse.up

        logger.debug 'Drag and drop completed'
      end
    end
  end
end
