# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Accept a cookie consent banner.
    #
    # Scans every live frame (open shadow roots included) for an accept
    # button inside a consent banner, never a refusal or a settings entry,
    # clicks it and checks the banner closed. Consent platforms whose
    # banner cannot be clicked (closed shadow root) are answered through
    # their JavaScript API. See CookieConsent for the heuristics.
    class AcceptCookiesTool < BaseTool
      tool_name 'accept_cookies'
      description 'Detect a cookie consent banner and accept all cookies. Only clicks an accept button inside a ' \
                  'consent banner (never a refusal or "continue without accepting"), checks that the banner ' \
                  'closed and returns the label it clicked'

      param :wait, type: :number, default: 3,
                   description: 'Seconds to wait for the cookie banner to appear (default: 3)'

      POLL_INTERVAL = 0.25
      # Seconds a banner gets to close after the click (fade-out animations)
      CLOSE_TIMEOUT = 3

      def perform(params)
        ensure_browser_active
        deadline = monotonic_now + params[:wait].to_f

        loop do
          outcome = attempt
          return outcome if outcome
          break if monotonic_now >= deadline

          sleep POLL_INTERVAL
        end

        error_response('No cookie consent banner found or unable to accept')
      end

      private

      # nil when there is nothing to accept yet
      def attempt
        button = find_button
        return accept_through_cmp_api if button.nil?
        return accepted(button) if click_and_confirm(button)

        accept_through_cmp_api ||
          error_response("Clicked \"#{button[:label]}\" but the cookie banner is still visible")
      end

      # Best accept button over every live frame: { frame:, label:, score:, known: }
      def find_button
        live_frames.filter_map { |frame, url| scan(frame, url) }.max_by { |button| button[:score] }
      end

      def scan(frame, url)
        found = frame.evaluate(CookieConsent::SCAN_JS, CookieConsent::KNOWN_ACCEPT_SELECTORS,
                               CookieConsent::ACCEPT_TIERS, CookieConsent::REJECT_PATTERNS,
                               CookieConsent::CONSENT_HINT)
        found && { frame: frame, url: url, label: found['label'], score: found['score'], known: found['known'] }
      rescue Ferrum::DeadBrowserError
        raise
      rescue StandardError => e
        logger.debug "Cookie scan failed in a frame: #{e.message}"
        nil
      end

      # [frame, url] pairs, main frame first; stale frames are skipped (they
      # hang Ferrum, see FrameTree). The main frame's url is nil.
      def live_frames
        urls = FrameTree.urls(page)
        main_id = page.main_frame.id
        page.frames.select { |frame| urls.key?(frame.id) }
            .sort_by { |frame| frame.id == main_id ? 0 : 1 }
            .map { |frame| [frame, frame.id == main_id ? nil : urls[frame.id]] }
      end

      # A real click first; if the banner stays, a DOM click (the button may
      # sit under an overlay) before giving up.
      def click_and_confirm(button)
        frame = button[:frame]
        begin
          frame.evaluate('window.__fmcpCookieButton').click
          return true if closed?(frame, CLOSE_TIMEOUT)
        rescue Ferrum::DeadBrowserError
          raise
        rescue StandardError => e
          logger.debug "Native click on cookie button failed: #{e.message}"
        end

        frame.evaluate(CookieConsent::JS_CLICK)
        closed?(frame, CLOSE_TIMEOUT)
      rescue Ferrum::DeadBrowserError
        raise
      rescue StandardError => e
        # The frame went away with the banner (navigation, removed iframe)
        logger.debug "Cookie banner frame gone after click: #{e.message}"
        true
      end

      def closed?(frame, timeout)
        deadline = monotonic_now + timeout
        loop do
          return true if frame.evaluate(CookieConsent::CLOSED_JS)
          return false if monotonic_now >= deadline

          sleep POLL_INTERVAL
        end
      end

      def accepted(button)
        data = { message: 'Cookie consent accepted', strategy: button[:known] ? 'known_cmp' : 'text',
                 clicked: button[:label] }
        data[:frame] = button[:url] if button[:url]
        success_response(data)
      end

      # "Accept all" through the platform's API, for banners a click cannot reach
      def accept_through_cmp_api
        cmp = page.evaluate(CookieConsent::PENDING_CMP_JS)
        return unless cmp

        page.evaluate(CookieConsent::ACCEPT_CMP_JS, cmp)
        deadline = monotonic_now + CLOSE_TIMEOUT
        sleep POLL_INTERVAL while page.evaluate(CookieConsent::PENDING_CMP_JS) == cmp && monotonic_now < deadline
        return if page.evaluate(CookieConsent::PENDING_CMP_JS) == cmp

        success_response(message: 'Cookie consent accepted', strategy: 'cmp_api', cmp: cmp)
      rescue Ferrum::DeadBrowserError
        raise
      rescue StandardError => e
        logger.debug "CMP API accept failed: #{e.message}"
        nil
      end
    end
  end
end
