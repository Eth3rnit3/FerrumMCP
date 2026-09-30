# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Base class for tools that operate on a browser session.
    #
    # Subclasses declare their interface with the Definition DSL and implement
    # #perform(params). Params arrive with symbol keys and defaults applied.
    #
    # Selectors accepted everywhere an element is looked up:
    #   - CSS:            "#login button"
    #   - XPath:          "xpath://button[@type='submit']" or "//button[...]"
    #   - Snapshot ref:   "ref:e12" (from the snapshot tool)
    class BaseTool
      extend Definition
      include Responses

      requires_session true

      REF_SELECTOR = /\Aref:(e\d+)\z/
      REF_ATTRIBUTE = 'data-fmcp-ref'
      POLL_INTERVAL = 0.1

      attr_reader :logger

      # progress: optional callable (current, total, message) sending an MCP
      # progress notification to the client that made the call.
      def initialize(browser_manager, progress: nil)
        @browser_manager = browser_manager
        @logger = browser_manager.logger
        @progress = progress
      end

      # Entry point used by the server and the specs. Any error raised by
      # #perform becomes an error response, so tools only rescue what they
      # handle differently (a fallback, a retry).
      def execute(raw_params)
        perform(self.class.normalize_params(raw_params))
      rescue Ferrum::DeadBrowserError
        # The session marks its browser dead and restarts it on the next call
        raise
      rescue StandardError => e
        failure_response(e)
      end

      def perform(_params)
        raise NotImplementedError, 'Subclasses must implement #perform'
      end

      protected

      # Ferrum::Browser of the session
      def browser
        @browser_manager.browser
      end

      # Current tab (Ferrum::Page). Tools act on the page, not the browser, so
      # tab switching works.
      def page
        @browser_manager.page
      end

      def ensure_browser_active
        raise BrowserError, 'Browser is not active' unless @browser_manager.active?
      end

      # Tell the client where a long operation stands (no-op without a channel)
      def report_progress(current, total: nil, message: nil)
        @progress&.call(current, total, message)
      end

      # Resolve a selector string into [:css, selector] or [:xpath, expression]
      def resolve_selector(selector)
        selector = selector.to_s.strip
        if (match = REF_SELECTOR.match(selector))
          [:css, %([#{REF_ATTRIBUTE}="#{match[1]}"])]
        elsif selector.start_with?('xpath:')
          [:xpath, selector.delete_prefix('xpath:')]
        elsif selector.start_with?('//', '(//')
          [:xpath, selector]
        else
          [:css, selector]
        end
      end

      # Find the first element matching the selector, polling until timeout.
      def find_element(selector, timeout: 5, within: page)
        deadline = monotonic_now + timeout.to_f

        loop do
          element = first_match(selector, within)
          return element if element

          raise ToolError, "Element not found: #{selector}" if monotonic_now > deadline

          sleep POLL_INTERVAL
        end
      rescue Ferrum::NodeNotFoundError
        raise ToolError, "Element not found: #{selector}"
      end

      # All elements matching the selector (no waiting)
      def find_elements(selector, within: page)
        kind, expression = resolve_selector(selector)
        kind == :xpath ? within.xpath(expression) : within.css(expression)
      end

      def first_match(selector, within = page)
        kind, expression = resolve_selector(selector)
        kind == :xpath ? within.at_xpath(expression) : within.at_css(expression)
      end

      # Retry logic for stale/moving elements
      def with_retry(retries: 3)
        attempts = 0
        begin
          attempts += 1
          yield
        rescue Ferrum::NodeMovingError => e
          raise ToolError, "Element became stale after #{retries} retries" unless attempts < retries

          logger.debug "Retry #{attempts}/#{retries} due to: #{e.class}"
          sleep POLL_INTERVAL
          retry
        end
      end

      # Visible = rendered with a size and not hidden through CSS
      def element_visible?(element)
        return false unless element

        page.evaluate(<<~JS, element)
          (function(el) {
            if (!el) return false;
            const rect = el.getBoundingClientRect();
            const style = window.getComputedStyle(el);
            return rect.width > 0 && rect.height > 0 &&
                   style.visibility !== 'hidden' && style.display !== 'none';
          })(arguments[0])
        JS
      rescue StandardError => e
        logger.debug "Error checking element visibility: #{e.message}"
        false
      end

      # Escape a string for use inside an XPath expression
      def xpath_literal(text)
        return "'#{text}'" unless text.include?("'")

        parts = text.split("'", -1).map { |part| "'#{part}'" }
        "concat(#{parts.join(%(, "'", ))})"
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
