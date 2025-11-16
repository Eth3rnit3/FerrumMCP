# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to automatically accept cookie consent banners
    # Uses multiple strategies to find and click accept buttons
    # rubocop:disable Metrics/ClassLength
    class AcceptCookiesTool < BaseTool
      def self.tool_name
        'accept_cookies'
      end

      def self.description
        'Automatically detect and accept cookie consent banners using multiple detection strategies'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            wait: {
              type: 'number',
              description: 'Seconds to wait for cookie banner to appear (default: 3)',
              default: 3
            },
            session_id: {
              type: 'string',
              description: 'Session ID to use for this operation'
            }
          },
          required: %w[session_id]
        }
      end

      # Common text patterns for cookie accept buttons (multiple languages)
      # Patterns are ordered from most specific to least specific to avoid false positives
      ACCEPT_PATTERNS = [
        # English
        'accept all cookies', 'accept all', 'accept cookies', 'accept and continue',
        'allow all', 'allow cookies', 'agree and continue', 'i accept', 'agree', 'consent',
        'i agree', 'got it', 'continue',
        # French
        'accepter et continuer', 'tout accepter', 'accepter tout', 'accepter les cookies',
        'accepter', 'j\'accepte', 'd\'accord', 'autoriser tout', 'autoriser', 'consentir',
        # German
        'alle akzeptieren', 'akzeptieren', 'zustimmen', 'einverstanden',
        # Spanish
        'aceptar todas', 'aceptar todo', 'aceptar', 'de acuerdo', 'acepto',
        # Italian
        'accetta tutto', 'accetta', 'accetto', 'acconsento',
        # Portuguese
        'aceitar tudo', 'aceitar', 'aceito', 'concordo'
      ].freeze

      # Common reject patterns to avoid clicking
      REJECT_PATTERNS = %w[
        reject refuse decline deny refuser ablehnen
        rechazar rifiuta recusar customize personaliser
        settings options manage gérer
      ].freeze

      def execute(params)
        ensure_browser_active
        wait_time = param(params, :wait) || 3

        logger.info 'Attempting to accept cookies using multiple strategies...'

        # Wait a bit for cookie banner to appear
        sleep wait_time

        # Try different strategies in order
        # iframe_detection is tried early because many sites use iframes for cookie banners
        # aria_labels is disabled for now as it causes too many false positives
        strategies = [
          method(:try_common_frameworks),
          method(:try_iframe_detection),
          method(:try_text_based_detection),
          method(:try_css_selectors)
        ]

        strategies.each_with_index do |strategy, index|
          logger.debug "Trying strategy #{index + 1}/#{strategies.length}: #{strategy.name}"

          result = strategy.call
          if result[:found]
            return success_response(
              message: 'Cookie consent accepted successfully',
              strategy: strategy.name.to_s.gsub('try_', ''),
              selector: result[:selector]
            )
          end
        end

        error_response('No cookie consent banner found or unable to accept')
      rescue StandardError => e
        logger.error "Accept cookies failed: #{e.message}"
        error_response("Failed to accept cookies: #{e.message}")
      end

      private

      # Strategy 1: Try known cookie consent frameworks
      def try_common_frameworks
        logger.debug 'Trying common frameworks detection...'

        # OneTrust
        selectors = [
          '#onetrust-accept-btn-handler',
          '.onetrust-close-btn-handler',
          '#accept-recommended-btn-handler',

          # Cookiebot
          '#CybotCookiebotDialogBodyLevelButtonLevelOptinAllowAll',
          '#CybotCookiebotDialogBodyButtonAccept',
          '.CybotCookiebotDialogBodyButton',

          # Cookie Notice
          '#cookie-notice-accept',
          '.cookie-notice-accept-button',

          # Osano
          '.osano-cm-accept-all',
          '.osano-cm-dialog__close',

          # Quantcast
          '.qc-cmp2-summary-buttons > button[mode="primary"]',
          'button[aria-label="AGREE"]',

          # TrustArc
          '#truste-consent-button',
          '.truste-button1',

          # Termly
          '#consent-accept-all',
          '.consent-accept-all-button',

          # Didomi
          '#didomi-notice-agree-button',
          '.didomi-continue-without-agreeing'
        ]

        try_selectors(selectors)
      end

      # Strategy 2: Text-based detection with XPath
      def try_text_based_detection
        logger.debug 'Trying text-based detection...'

        ACCEPT_PATTERNS.each do |pattern|
          # Try buttons first
          elements = find_elements_by_text(pattern, tag: 'button')
          next if elements.empty?

          # Filter: must be visible AND not a reject button AND text should actually contain the pattern
          accept_button = elements.find do |el|
            next unless element_visible?(el)

            text = el.text.downcase.strip
            # Verify the pattern is actually in the text (not just a substring match)
            next unless text.include?(pattern.downcase)

            # Make sure it's not a reject button
            REJECT_PATTERNS.none? { |reject| text.include?(reject) }
          end

          next unless accept_button

          if click_element(accept_button)
            xpath = build_xpath_for_text(pattern, 'button')
            return { found: true, selector: "xpath:#{xpath}" }
          end

          # Try links if buttons didn't work
          elements = find_elements_by_text(pattern, tag: 'a')
          next if elements.empty?

          accept_link = elements.find do |el|
            next unless element_visible?(el)

            text = el.text.downcase.strip
            next unless text.include?(pattern.downcase)

            REJECT_PATTERNS.none? { |reject| text.include?(reject) }
          end

          next unless accept_link

          if click_element(accept_link)
            xpath = build_xpath_for_text(pattern, 'a')
            return { found: true, selector: "xpath:#{xpath}" }
          end
        end

        { found: false }
      end

      # Strategy 3: Common CSS selectors and classes
      def try_css_selectors
        logger.debug 'Trying CSS selectors detection...'

        selectors = [
          # Generic accept buttons
          'button[class*="accept"]',
          'button[class*="consent"]',
          'button[class*="agree"]',
          'a[class*="accept"]',
          'a[class*="consent"]',

          # Common IDs
          '#accept-cookies',
          '#acceptCookies',
          '#cookie-accept',
          '#cookieAccept',
          '#cookies-accept',

          # Common classes
          '.accept-cookies',
          '.accept-all',
          '.cookie-accept',
          '.cookies-accept',
          '.consent-accept',
          '.btn-accept',

          # Data attributes
          '[data-action="accept"]',
          '[data-cookie="accept"]',
          '[data-consent="accept"]',
          '[data-cookie-consent="accept"]'
        ]

        try_selectors(selectors)
      end

      # Strategy 4: ARIA labels
      def try_aria_labels
        logger.debug 'Trying ARIA labels detection...'

        ACCEPT_PATTERNS.each do |pattern|
          selectors = [
            "button[aria-label*=\"#{pattern}\" i]",
            "a[aria-label*=\"#{pattern}\" i]"
          ]

          result = try_selectors(selectors)
          return result if result[:found]
        end

        { found: false }
      end

      # Strategy 5: Check iframes for cookie banners
      def try_iframe_detection
        logger.debug 'Trying iframe detection...'

        # Get all iframes
        iframes = browser.css('iframe')
        return { found: false } if iframes.empty?

        logger.debug "Found #{iframes.length} iframe(s), checking for cookie banners..."

        iframes.each_with_index do |_iframe, index|
          # Try to access iframe content
          frame = browser.frames[index]
          next unless frame

          # Switch to iframe context
          browser.switch_to_frame(frame)

          # Try strategies within iframe (in order of effectiveness)
          result = try_common_frameworks
          if result[:found]
            browser.switch_to_default_content
            return { found: true, selector: "iframe[#{index}] > #{result[:selector]}" }
          end

          result = try_text_based_detection
          if result[:found]
            browser.switch_to_default_content
            return { found: true, selector: "iframe[#{index}] > #{result[:selector]}" }
          end

          result = try_css_selectors
          if result[:found]
            browser.switch_to_default_content
            return { found: true, selector: "iframe[#{index}] > #{result[:selector]}" }
          end

          # Switch back to main context
          browser.switch_to_default_content
        rescue StandardError => e
          logger.debug "Cannot access iframe #{index}: #{e.message}"
          begin
            browser.switch_to_default_content
          rescue StandardError
            nil
          end
        end

        { found: false }
      end

      # Helper: Try multiple CSS selectors
      def try_selectors(selectors)
        selectors.each do |selector|
          element = browser.at_css(selector)
          next unless element

          # Check if element is visible
          next unless element_visible?(element)

          # Check if it's not a reject button
          text = begin
            element.text.downcase.strip
          rescue StandardError
            ''
          end
          next if REJECT_PATTERNS.any? { |reject| text.include?(reject) }

          if click_element(element)
            logger.info "Successfully clicked: #{selector}"
            return { found: true, selector: selector }
          end
        rescue StandardError => e
          logger.debug "Selector '#{selector}' failed: #{e.message}"
        end

        { found: false }
      end

      # Helper: Find elements by text content
      def find_elements_by_text(text, tag: '*')
        escaped_text = escape_xpath_string(text)
        xpath = "//#{tag}[contains(translate(normalize-space(.), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', " \
                "'abcdefghijklmnopqrstuvwxyz'), #{escaped_text})]"

        browser.xpath(xpath)
      rescue StandardError => e
        logger.debug "XPath search for '#{text}' failed: #{e.message}"
        []
      end

      # Helper: Build XPath for text
      def build_xpath_for_text(text, tag)
        escaped_text = escape_xpath_string(text)
        "//#{tag}[contains(translate(normalize-space(.), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', " \
          "'abcdefghijklmnopqrstuvwxyz'), #{escaped_text})]"
      end

      # Helper: Escape XPath string
      def escape_xpath_string(text)
        return "'#{text.downcase}'" unless text.include?("'")

        parts = text.downcase.split("'")
        quoted_parts = parts.map { |part| "'#{part}'" }
        "concat(#{quoted_parts.join(", \"'\", ")})"
      end

      # Helper: Click element with retry and fallback to JavaScript
      def click_element(element)
        return false unless element

        # Try native click first
        element.scroll_into_view if element.respond_to?(:scroll_into_view)
        element.click
        sleep 0.5 # Wait for any animations
        true
      rescue StandardError => e
        logger.debug "Native click failed: #{e.message}, trying JavaScript..."

        # Fallback to JavaScript click
        begin
          browser.execute(<<~JAVASCRIPT, element)
            arguments[0].scrollIntoView({ behavior: 'instant', block: 'center' });
            arguments[0].click();
          JAVASCRIPT
          sleep 0.5
          true
        rescue StandardError => js_error
          logger.debug "JavaScript click also failed: #{js_error.message}"
          false
        end
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
