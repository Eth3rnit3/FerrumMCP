# frozen_string_literal: true

module FerrumMCP
  module Captcha
    # Cloudflare Turnstile, both the embedded widget and the full-page
    # "Just a moment..." interstitial.
    #
    # The checkbox lives in a cross-origin iframe attached to a closed shadow
    # root, so it is clicked at viewport coordinates computed from the iframe
    # owner box. Many sites run Turnstile in non-interactive mode, so the solver
    # first gives it a few seconds to pass on its own.
    class TurnstileSolver < BaseSolver
      DEFAULT_ATTEMPTS = 3
      CHECKBOX_OFFSET_X = 30 # centre of the checkbox from the widget's left edge

      TOKEN_JS = <<~JS
        (() => {
          const input = document.querySelector('input[name="cf-turnstile-response"]');
          if (input && input.value) return input.value;
          try {
            const value = window.turnstile && window.turnstile.getResponse();
            if (value) return value;
          } catch (e) {}
          return null;
        })()
      JS

      INTERSTITIAL_JS = <<~JS
        /just a moment|un instant|checking your browser|verify you are human/i.test(document.title) ||
          !!document.querySelector('#challenge-form, #challenge-stage, .cf-browser-verification')
      JS

      # Cloudflare's block page replaces the interstitial when the visitor is
      # refused outright (WAF rule, IP reputation).
      BLOCKED_JS = <<~JS
        /sorry, you have been blocked|attention required|access denied/i.test(document.title) ||
          !!document.querySelector('#cf-error-details, .cf-error-details, #cf-wrapper .cf-error-overview')
      JS

      def solve
        @interstitial = interstitial?
        state = wait_until(4) { current_state }
        return outcome(state, 0) if state

        max_attempts.times do |attempt|
          box = wait_until(8) { current_state || widget_box }
          return unsolved(:failed, 'Turnstile widget did not render', attempts: attempt) unless box
          return outcome(box, attempt) if box.is_a?(Symbol)

          click_checkbox(box)
          state = wait_until(15) { current_state }
          return outcome(state, attempt + 1) if state
        end

        unsolved(:failed, "Turnstile did not issue a token after #{max_attempts} clicks (the browser " \
                          'fingerprint or IP reputation was rejected)', attempts: max_attempts)
      end

      protected

      def type
        :turnstile
      end

      private

      def max_attempts
        [options.fetch(:max_attempts, DEFAULT_ATTEMPTS), DEFAULT_ATTEMPTS].min
      end

      # The widget iframe runs out of process (see Session#default_browser_options),
      # so it is located through the pierced DOM rather than page.frames.
      def widget_box
        iframe_boxes(Detector::FRAME_PATTERNS[:turnstile]).find { |box| box[:width] > 100 && box[:height] > 30 }
      end

      def click_checkbox(box)
        logger.info 'Turnstile: clicking the checkbox'
        pause(0.5, 1.2)
        x = box[:x] + [CHECKBOX_OFFSET_X, box[:width] / 2].min + rand(-4.0..4.0)
        y = box[:y] + (box[:height] / 2) + rand(-4.0..4.0)
        human_click(x, y)
      end

      # :blocked, :passed or nil while the challenge is still running. The block
      # page is checked first: it also makes the interstitial "disappear".
      def current_state
        return :blocked if blocked?

        :passed if passed?
      end

      def outcome(state, attempts)
        state == :blocked ? blocked(attempts) : solved(attempts)
      end

      def interstitial?
        page.evaluate(INTERSTITIAL_JS)
      rescue StandardError
        false
      end

      def blocked?
        page.evaluate(BLOCKED_JS)
      rescue StandardError
        false
      end

      # The interstitial is passed once Cloudflare navigates to the real page.
      def passed?
        return !interstitial? if @interstitial

        !token.nil?
      end

      def token
        page.evaluate(TOKEN_JS)
      rescue StandardError
        nil
      end

      def solved(attempts)
        message = @interstitial ? 'Cloudflare challenge passed' : 'Turnstile solved'
        Result.solved(type, token: token, attempts: attempts, message: message)
      end

      def blocked(attempts)
        unsolved(:blocked,
                 'Cloudflare blocked this visitor ("Sorry, you have been blocked"): the IP or browser is refused ' \
                 'by the site\'s firewall. Solving is not possible; retry from another IP or a BotBrowser session.',
                 attempts: attempts)
      end
    end
  end
end
