# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Press keyboard keys
    class PressKeyTool < BaseTool
      tool_name 'press_key'
      description 'Press a keyboard key (e.g. Enter, Tab, Escape, ArrowDown) or type a character'

      param :key, type: :string, required: true, description: 'Key to press (Enter, Tab, Escape, ArrowDown, etc.)'
      param :selector, type: :string, description: 'Optional: selector of the element to focus before pressing the key'

      KEY_ALIASES = {
        'enter' => :Enter, 'return' => :Enter, 'tab' => :Tab, 'escape' => :Escape, 'esc' => :Escape,
        'backspace' => :Backspace, 'delete' => :Delete, 'del' => :Delete,
        'arrowdown' => :Down, 'down' => :Down, 'arrowup' => :Up, 'up' => :Up,
        'arrowleft' => :Left, 'left' => :Left, 'arrowright' => :Right, 'right' => :Right,
        'space' => ' ', 'pageup' => :PageUp, 'pagedown' => :PageDown, 'home' => :Home, 'end' => :End
      }.freeze

      def perform(params)
        key = params[:key].to_s
        selector = params[:selector]

        if selector
          logger.info "Focusing element: #{selector}"
          find_element(selector).focus
        end

        logger.info "Pressing key: #{key}"
        page.keyboard.type(normalize_key(key))

        success_response(message: "Pressed key: #{key}")
      end

      private

      def normalize_key(key)
        KEY_ALIASES.fetch(key.downcase) { key.length == 1 ? key : key.to_sym }
      end
    end
  end
end
