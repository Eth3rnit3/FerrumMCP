# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Drag and drop
    class DragAndDropTool < BaseTool
      tool_name 'drag_and_drop'
      description 'Drag an element and drop it onto another element or at coordinates'

      param :source_selector, type: :string, required: true, description: 'Selector of the element to drag'
      param :target_selector, type: :string, description: 'Selector of the drop target (or use target_x/target_y)'
      param :target_x, type: :number, description: 'X coordinate to drop at (alternative to target_selector)'
      param :target_y, type: :number, description: 'Y coordinate to drop at (alternative to target_selector)'
      param :steps, type: :number, default: 10, description: 'Number of intermediate mouse moves (default: 10)'

      def perform(params)
        source = params[:source_selector]
        target = params[:target_selector]
        logger.info "Dragging #{source} to #{target || "(#{params[:target_x]}, #{params[:target_y]})"}"

        from_x, from_y = center_of(find_element(source))
        to_x, to_y = if target
                       center_of(find_element(target))
                     elsif params[:target_x] && params[:target_y]
                       [params[:target_x], params[:target_y]]
                     else
                       raise ToolError, 'Either target_selector or both target_x and target_y must be provided'
                     end

        perform_drag(from_x, from_y, to_x, to_y, params[:steps].to_i.clamp(1, 200))

        success_response(message: "Dragged from (#{from_x.round}, #{from_y.round}) to (#{to_x.round}, #{to_y.round})")
      rescue StandardError => e
        logger.error "Drag and drop failed: #{e.message}"
        error_response("Failed to drag and drop: #{e.message}")
      end

      private

      def center_of(element)
        center = page.evaluate(<<~JS, element)
          (function(el) {
            const rect = el.getBoundingClientRect();
            return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
          })(arguments[0])
        JS
        [center['x'], center['y']]
      end

      def perform_drag(from_x, from_y, to_x, to_y, steps)
        mouse = page.mouse
        mouse.move(x: from_x, y: from_y)
        sleep 0.05
        mouse.down
        sleep 0.05

        delay = [0.3 / steps, 0.01].max
        (1..steps).each do |step|
          progress = step / steps.to_f
          mouse.move(x: from_x + ((to_x - from_x) * progress), y: from_y + ((to_y - from_y) * progress))
          sleep delay
        end

        sleep 0.05
        mouse.up
      end
    end
  end
end
