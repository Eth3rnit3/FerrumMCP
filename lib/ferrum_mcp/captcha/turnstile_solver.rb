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

      def solve
        @interstitial = interstitial?
        return solved(0) if passed?
        return solved(0) if wait_until(4) { passed? }

        max_attempts.times do |attempt|
          frame = wait_until(8) { visible_frame }
          return unsolved(:failed, 'Turnstile widget did not render', attempts: attempt) unless frame

          click_checkbox(frame)
          return solved(attempt + 1) if wait_until(15) { passed? }
        end

        unsolved(:failed, "Turnstile did not issue a token after #{max_attempts} clicks. The browser is likely " \
                          'fingerprinted as automated; try a BotBrowser session.', attempts: max_attempts)
      end

      protected

      def type
        :turnstile
      end

      private

      def max_attempts
        [options.fetch(:max_attempts, DEFAULT_ATTEMPTS), DEFAULT_ATTEMPTS].min
      end

      def visible_frame
        frames_matching(Detector::FRAME_PATTERNS[:turnstile]).find { |frame| frame_visible?(frame) }
      end

      def click_checkbox(frame)
        box = frame_box(frame)
        return unless box

        logger.info 'Turnstile: clicking the checkbox'
        pause(0.5, 1.2)
        x = box[:x] + [CHECKBOX_OFFSET_X, box[:width] / 2].min + rand(-4.0..4.0)
        y = box[:y] + (box[:height] / 2) + rand(-4.0..4.0)
        human_click(x, y)
      end

      def interstitial?
        page.evaluate(INTERSTITIAL_JS)
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
    end
  end
end
