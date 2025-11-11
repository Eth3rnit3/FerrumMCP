# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to press keyboard keys
    class PressKeyTool < BaseTool
      def self.tool_name
        'press_key'
      end

      def self.description
        'Press keyboard keys (e.g., Enter, Tab, Escape)'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            key: {
              type: 'string',
              description: 'Key to press (Enter, Tab, Escape, ArrowDown, etc.)'
            },
            selector: {
              type: 'string',
              description: 'Optional: CSS selector to focus before pressing key'
            }
          },
          required: ['key']
        }
      end

      def execute(params)
        key = params['key'] || params[:key]
        selector = params['selector'] || params[:selector]

        if selector
          logger.info "Focusing element: #{selector}"
          element = find_element(selector)
          element.focus
        end

        logger.info "Pressing key: #{key}"
        # Use keyboard.type for single key press to avoid duplication issues
        # keyboard.down + keyboard.up was causing duplicate characters
        normalized_key = normalize_key(key)
        browser.keyboard.type(normalized_key)

        success_response(message: "Pressed key: #{key}")
      rescue StandardError => e
        logger.error "Press key failed: #{e.message}"
        error_response("Failed to press key: #{e.message}")
      end

      private

      def normalize_key(key)
        # Convert common key names to Ferrum format
        case key.to_s.downcase
        when 'enter', 'return'
          :Enter
        when 'tab'
          :Tab
        when 'escape', 'esc'
          :Escape
        when 'backspace'
          :Backspace
        when 'delete', 'del'
          :Delete
        when 'arrowdown', 'down'
          :Down
        when 'arrowup', 'up'
          :Up
        when 'arrowleft', 'left'
          :Left
        when 'arrowright', 'right'
          :Right
        when 'space'
          ' '
        else
          # If already a symbol, return as-is, otherwise try to convert
          key.is_a?(Symbol) ? key : key.to_sym
        end
      end
    end
  end
end
