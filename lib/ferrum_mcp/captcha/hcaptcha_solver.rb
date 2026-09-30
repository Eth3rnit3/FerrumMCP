# frozen_string_literal: true

module FerrumMCP
  module Captcha
    # hCaptcha checkbox.
    #
    # hCaptcha removed its audio challenge, so only the checkbox can be solved
    # automatically: it passes when the browser looks trustworthy. When a visual
    # challenge shows up the solver reports :challenge_required (the tool
    # attaches a screenshot so the calling agent can decide what to do).
    class HcaptchaSolver < BaseSolver
      TOKEN_JS = <<~JS
        (() => {
          const area = [...document.querySelectorAll('textarea[name="h-captcha-response"]')].find((a) => a.value);
          if (area) return area.value;
          const frame = [...document.querySelectorAll('iframe[data-hcaptcha-response]')]
            .find((f) => f.getAttribute('data-hcaptcha-response'));
          return frame ? frame.getAttribute('data-hcaptcha-response') : null;
        })()
      JS

      CHALLENGE_VISIBLE_JS = <<~JS
        [...document.querySelectorAll('iframe[src*="hcaptcha"][src*="frame=challenge"]')].some((frame) => {
          const rect = frame.getBoundingClientRect();
          return getComputedStyle(frame).visibility !== 'hidden' && rect.width > 1 && rect.height > 1 && rect.bottom > 0;
        })
      JS

      def solve
        return solved if token

        checkbox_frame = frames_matching(Detector::FRAME_PATTERNS[:hcaptcha]).find { |frame| frame_visible?(frame) }
        return unsolved(:failed, 'hCaptcha checkbox is not visible') unless checkbox_frame

        logger.info 'hCaptcha: clicking the checkbox'
        pause(0.4, 1.0)
        human_click_node(checkbox_frame.at_css('#checkbox'))

        outcome = wait_until(10) do
          if token then :solved
          elsif page.evaluate(CHALLENGE_VISIBLE_JS) then :challenge
          end
        end

        case outcome
        when :solved then solved
        when :challenge
          unsolved(:challenge_required,
                   'hCaptcha asked for a visual challenge, which cannot be solved automatically ' \
                   '(hCaptcha has no audio challenge). A BotBrowser session is more likely to pass the checkbox.')
        else
          unsolved(:failed, 'hCaptcha did not react to the checkbox click')
        end
      end

      protected

      def type
        :hcaptcha
      end

      private

      def token
        page.evaluate(TOKEN_JS)
      rescue StandardError
        nil
      end

      def solved
        Result.solved(type, token: token, attempts: 1, message: 'hCaptcha solved')
      end
    end
  end
end
