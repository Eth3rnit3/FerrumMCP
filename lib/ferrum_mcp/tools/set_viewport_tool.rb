# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Change the viewport size
    class SetViewportTool < BaseTool
      tool_name 'set_viewport'
      description 'Set the viewport size (and optionally device scale factor / mobile emulation) of the current tab'

      param :width, type: :integer, required: true, description: 'Viewport width in pixels'
      param :height, type: :integer, required: true, description: 'Viewport height in pixels'
      param :scale_factor, type: :number, default: 0, description: 'Device scale factor (0 keeps the default)'
      param :mobile, type: :boolean, default: false, description: 'Emulate a mobile device (default: false)'

      def perform(params)
        ensure_browser_active
        width = params[:width].to_i
        height = params[:height].to_i
        raise ToolError, 'width and height must be positive' unless width.positive? && height.positive?

        logger.info "Setting viewport to #{width}x#{height}"
        page.set_viewport(width: width, height: height, scale_factor: params[:scale_factor].to_f,
                          mobile: params[:mobile] ? true : false)

        success_response(width: width, height: height, mobile: params[:mobile] ? true : false)
      end
    end
  end
end
