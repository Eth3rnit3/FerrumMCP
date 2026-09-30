# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Click on an element
    class ClickTool < BaseTool
      tool_name 'click'
      description 'Click on an element using a CSS selector, an XPath (xpath: prefix) or a snapshot ref (ref:eN)'

      param :selector, type: :string, required: true,
                       description: 'CSS selector, XPath (xpath: prefix) or snapshot ref (ref:e12) of the element'
      param :wait, type: :number, default: 5, description: 'Seconds to wait for the element (default: 5)'
      param :force, type: :boolean, default: false,
                    description: 'Force click through JavaScript when the element is hidden (default: false)'

      # Seconds to watch for a tab opened by the click (target=_blank, window.open).
      # Chrome creates it while dispatching the click; every click pays this wait.
      NEW_TAB_WAIT = 0.15
      # Seconds the new tab gets to leave about:blank
      NEW_TAB_LOAD = 5

      # A click that opens a tab moves the session to it, as the browser
      # moves the user, and says so in `new_tab`.
      def perform(params)
        before = tab_ids
        response = click(params)
        tab = wait_for_new_tab(before)
        return response unless tab

        follow(tab, response)
      end

      private

      def tab_ids
        @browser_manager.pages.map(&:target_id)
      end

      def wait_for_new_tab(before)
        deadline = monotonic_now + NEW_TAB_WAIT
        loop do
          tab = @browser_manager.pages.find { |p| !before.include?(p.target_id) }
          return tab if tab || monotonic_now >= deadline

          sleep POLL_INTERVAL
        end
      rescue Ferrum::DeadBrowserError
        raise
      rescue StandardError => e
        logger.debug "New tab lookup failed: #{e.message}"
        nil
      end

      def follow(tab, response)
        @browser_manager.select_page(tab)
        tab.command('Page.bringToFront')
        deadline = monotonic_now + NEW_TAB_LOAD
        sleep POLL_INTERVAL while tab.url.to_s.start_with?('about:blank') && monotonic_now < deadline
        logger.info "Click opened tab #{tab.target_id}, now the current tab"

        data = response[:data]
        success_response(data.merge(message: "#{data[:message]}; it opened a new tab, now the current one",
                                    new_tab: { tab_id: tab.target_id, url: tab.url, title: tab.title }))
      end

      def click(params)
        selector = params[:selector]
        force = params[:force]

        logger.info "Clicking element: #{selector} (force: #{force})"

        with_retry do
          element = find_clickable(selector, params[:wait])
          element.scroll_into_view
          element.click
        end

        success_response(message: "Clicked on #{selector}")
      rescue Ferrum::NodeNotFoundError, Ferrum::CoordinatesNotFoundError, Ferrum::NodeMovingError => e
        forced_click(selector, e, force)
      rescue Ferrum::BrowserError => e
        # Chrome cannot compute a position for an element without layout
        raise unless e.message.include?('layout object') || e.message.include?('not visible')

        forced_click(selector, e, force)
      end

      def forced_click(selector, error, force)
        raise ToolError, "#{error.message}. Try with force: true" unless force

        logger.warn "Native click failed, retrying with JavaScript: #{error.message}"
        click_with_javascript(selector)
        success_response(message: "Clicked on #{selector} (forced)")
      end

      # Prefer a visible match when several elements match
      def find_clickable(selector, timeout)
        element = find_element(selector, timeout: timeout)
        return element if element_visible?(element)

        visible = find_elements(selector).find { |el| element_visible?(el) }
        visible || element
      end

      def click_with_javascript(selector)
        logger.info "Using JavaScript click for: #{selector}"
        kind, expression = resolve_selector(selector)
        finder = if kind == :xpath
                   <<~JS
                     const result = document.evaluate(#{expression.inspect}, document, null,
                       XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
                     const elements = [];
                     for (let i = 0; i < result.snapshotLength; i++) elements.push(result.snapshotItem(i));
                   JS
                 else
                   "const elements = Array.from(document.querySelectorAll(#{expression.inspect}));"
                 end

        page.execute(<<~JS)
          #{finder}
          if (elements.length === 0) throw new Error('No element found for ' + #{selector.inspect});
          const visible = elements.find(el => el.offsetWidth > 0 && el.offsetHeight > 0);
          const target = visible || elements[0];
          const wasHidden = target.offsetWidth === 0 && target.offsetHeight === 0;
          const originalDisplay = target.style.display;
          const originalVisibility = target.style.visibility;
          if (wasHidden) { target.style.display = 'block'; target.style.visibility = 'visible'; }
          try {
            target.scrollIntoView({ behavior: 'instant', block: 'center' });
            target.click();
          } finally {
            if (wasHidden) { target.style.display = originalDisplay; target.style.visibility = originalVisibility; }
          }
        JS
      end
    end
  end
end
