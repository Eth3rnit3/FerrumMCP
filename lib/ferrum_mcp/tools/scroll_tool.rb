# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Scroll the window, a scrollable element, or an element into view
    class ScrollTool < BaseTool
      tool_name 'scroll'
      description 'Scroll the page (or a scrollable element) by direction/amount, to absolute coordinates, ' \
                  'or bring an element into view'

      param :selector, type: :string,
                       description: 'Optional: element to scroll into view, or the scrollable container to scroll ' \
                                    'when a direction is given'
      param :direction, type: :string, enum: %w[up down left right top bottom],
                        description: 'Direction to scroll (top/bottom jump to the extremes)'
      param :amount, type: :number, default: 500, description: 'Pixels to scroll for up/down/left/right (default: 500)'
      param :x, type: :number, description: 'Absolute horizontal scroll position'
      param :y, type: :number, description: 'Absolute vertical scroll position'

      def perform(params)
        ensure_browser_active
        selector = params[:selector]
        element = selector ? find_element(selector) : nil
        logger.info "Scrolling #{selector || 'window'} #{params[:direction] || ''}".strip

        position = page.evaluate(SCROLL_SCRIPT, element, params[:direction], params[:amount].to_f,
                                 params[:x], params[:y])

        success_response(x: position['x'], y: position['y'], target: position['target'])
      end

      SCROLL_SCRIPT = <<~JS
        (function(el, direction, amount, x, y) {
          if (el && !direction && x == null && y == null) {
            el.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'instant' });
            return { x: window.scrollX, y: window.scrollY, target: 'window' };
          }
          const isWindow = !el;
          const current = () => isWindow ? { x: window.scrollX, y: window.scrollY } : { x: el.scrollLeft, y: el.scrollTop };
          const max = isWindow
            ? { x: document.documentElement.scrollWidth, y: document.documentElement.scrollHeight }
            : { x: el.scrollWidth, y: el.scrollHeight };
          let next = current();
          if (x != null) next.x = x;
          if (y != null) next.y = y;
          switch (direction) {
            case 'up': next.y -= amount; break;
            case 'down': next.y += amount; break;
            case 'left': next.x -= amount; break;
            case 'right': next.x += amount; break;
            case 'top': next.y = 0; break;
            case 'bottom': next.y = max.y; break;
          }
          if (isWindow) window.scrollTo(next.x, next.y); else el.scrollTo(next.x, next.y);
          const after = current();
          return { x: after.x, y: after.y, target: isWindow ? 'window' : 'element' };
        })(arguments[0], arguments[1], arguments[2], arguments[3], arguments[4])
      JS
    end
  end
end
