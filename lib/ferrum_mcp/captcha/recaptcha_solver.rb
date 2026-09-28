# frozen_string_literal: true

require 'base64'

module FerrumMCP
  module Captcha
    # reCAPTCHA v2 (checkbox, invisible, enterprise) through the audio challenge.
    #
    # The widget is made of two iframes sharing a suffix: the anchor ("a-XYZ",
    # the checkbox) and the challenge frame ("c-XYZ", bframe). Google often asks
    # for several correct answers in a row, so the solver loops until the anchor
    # reports aria-checked="true", then reads the token from the host page.
    class RecaptchaSolver < BaseSolver
      BFRAME = %r{/recaptcha/(?:api2|enterprise)/bframe}
      DEFAULT_ATTEMPTS = 5

      # Evaluated in the challenge frame
      CHALLENGE_STATE_JS = <<~JS
        (() => {
          const shown = (sel) => [...document.querySelectorAll(sel)].some((el) =>
            el.getClientRects().length > 0 && getComputedStyle(el).visibility !== 'hidden');
          if (shown('.rc-doscaptcha-header, .rc-doscaptcha-body')) return 'blocked';
          const audio = document.querySelector('#audio-source');
          if (shown('#rc-audio, .rc-audiochallenge-control, #audio-response') && audio && audio.src) return 'audio';
          if (shown('#rc-imageselect, .rc-imageselect-payload')) return 'image';
          return null;
        })()
      JS

      AUDIO_ERROR_JS = <<~JS
        (() => {
          const el = document.querySelector('.rc-audiochallenge-error-message');
          return el && el.getClientRects().length > 0 ? el.innerText.trim() : '';
        })()
      JS

      FETCH_AUDIO_JS = <<~JS
        fetch(arguments[0], { credentials: 'include' })
          .then((response) => response.arrayBuffer())
          .then((buffer) => {
            const bytes = new Uint8Array(buffer);
            let binary = '';
            for (let i = 0; i < bytes.length; i += 0x8000) {
              binary += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
            }
            arguments[1](btoa(binary));
          })
          .catch(() => arguments[1](null));
      JS

      # Evaluated in the host page: is the challenge popup of this widget shown?
      CHALLENGE_VISIBLE_JS = <<~JS
        (() => {
          const frame = document.querySelector(`iframe[name="${arguments[0]}"]`) ||
                        document.querySelector('iframe[src*="/recaptcha/"][src*="bframe"]');
          if (!frame) return false;
          const rect = frame.getBoundingClientRect();
          return getComputedStyle(frame).visibility !== 'hidden' && rect.width > 0 && rect.height > 0 && rect.bottom > 0;
        })()
      JS

      # Evaluated in the host page: token of the widget whose anchor is arguments[0]
      TOKEN_JS = <<~JS
        (() => {
          let node = document.querySelector(`iframe[name="${arguments[0]}"]`);
          for (let i = 0; node && i < 6; i++, node = node.parentElement) {
            const area = node.querySelector && node.querySelector('textarea[name="g-recaptcha-response"]');
            if (area && area.value) return area.value;
          }
          const any = [...document.querySelectorAll('textarea[name="g-recaptcha-response"]')].find((a) => a.value);
          return any ? any.value : null;
        })()
      JS

      EXECUTE_INVISIBLE_JS = <<~JS
        (() => {
          const api = window.grecaptcha && (window.grecaptcha.enterprise || window.grecaptcha);
          if (!api || typeof api.execute !== 'function') return false;
          try { api.execute(); return true; } catch (e) { return false; }
        })()
      JS

      def solve
        @anchor = pick_anchor
        return unsolved(:failed, 'reCAPTCHA anchor frame not found') unless @anchor

        return solved(0) if checked?

        open_challenge
        state = wait_until(12) { checked? ? :checked : current_challenge }
        return solved(0) if state == :checked
        return blocked if state == 'blocked'
        return unsolved(:failed, 'reCAPTCHA challenge did not appear') unless state

        switch_to_audio if state == 'image'
        solve_audio_rounds
      end

      protected

      def type
        :recaptcha
      end

      private

      def max_attempts
        options.fetch(:max_attempts, DEFAULT_ATTEMPTS)
      end

      def transcriber
        @transcriber ||= options.fetch(:transcriber) do
          WhisperService.new(language: options[:language], logger: logger).ensure_ready!
        end
      end

      def pick_anchor
        anchors = frames_matching(Detector::FRAME_PATTERNS[:recaptcha])
        anchors.find { |frame| frame_visible?(frame) && !invisible?(frame) } || anchors.first
      end

      def invisible?(frame = @anchor)
        frame.url.include?('size=invisible')
      end

      def widget_suffix
        @anchor.name.to_s.delete_prefix('a-')
      end

      def challenge_frame
        frames = frames_matching(BFRAME)
        frames.find { |frame| frame.name.to_s == "c-#{widget_suffix}" } || frames.first
      end

      def checked?
        @anchor.at_css('#recaptcha-anchor')&.attribute('aria-checked') == 'true'
      end

      # Visible challenge kind ('audio', 'image', 'blocked') or nil
      def current_challenge
        return nil unless page.evaluate(CHALLENGE_VISIBLE_JS, "c-#{widget_suffix}")

        challenge_frame&.evaluate(CHALLENGE_STATE_JS)
      end

      def open_challenge
        if invisible?
          logger.info 'reCAPTCHA: invisible widget, calling grecaptcha.execute()'
          page.evaluate(EXECUTE_INVISIBLE_JS)
        else
          logger.info 'reCAPTCHA: clicking the checkbox'
          pause(0.4, 1.0)
          human_click_node(@anchor.at_css('#recaptcha-anchor'))
        end
      end

      def switch_to_audio
        logger.info 'reCAPTCHA: switching to the audio challenge'
        pause(0.8, 1.6)
        human_click_node(challenge_frame.at_css('#recaptcha-audio-button'))
        wait_until(8) { %w[audio blocked].include?(current_challenge) }
      end

      def solve_audio_rounds
        transcriptions = []

        max_attempts.times do |round|
          state = current_challenge
          return blocked(attempts: round, transcriptions: transcriptions) if state == 'blocked'
          return solved(round, transcriptions) if checked?

          source = audio_source
          return unsolved(:failed, 'reCAPTCHA audio challenge not available', attempts: round) unless source

          answer = transcribe(source)
          transcriptions << answer
          logger.info "reCAPTCHA: round #{round + 1} heard #{answer.inspect}"

          outcome = answer.empty? ? :reload : submit_answer(answer, source)
          case outcome
          when :solved then return solved(round + 1, transcriptions)
          when :blocked then return blocked(attempts: round + 1, transcriptions: transcriptions)
          when :reload then reload_challenge(source)
          end
        end

        unsolved(:failed, "reCAPTCHA not solved after #{max_attempts} audio challenges",
                 attempts: max_attempts, transcriptions: transcriptions)
      end

      def audio_source
        challenge_frame&.evaluate("(document.querySelector('#audio-source') || {}).src || null")
      end

      def transcribe(source)
        encoded = challenge_frame.evaluate_async(FETCH_AUDIO_JS, 20, source)
        raise ToolError, 'Could not download the reCAPTCHA audio' unless encoded

        transcriber.transcribe_bytes(Base64.decode64(encoded))
      end

      # Type the answer, press verify and classify what happened next.
      def submit_answer(answer, source)
        frame = challenge_frame
        input = frame.at_css('#audio-response')
        input.evaluate("this.value = ''")
        pause(1.0, 2.5) # time a person spends listening
        human_type(input, answer)
        pause(0.3, 0.8)
        human_click_node(frame.at_css('#recaptcha-verify-button'))

        outcome = wait_until(10) do
          if checked? then :solved
          elsif current_challenge == 'blocked' then :blocked
          elsif audio_source && audio_source != source then :next
          end
        end
        outcome || :reload
      end

      def reload_challenge(source)
        logger.info 'reCAPTCHA: requesting a new audio challenge'
        human_click_node(challenge_frame.at_css('#recaptcha-reload-button'))
        wait_until(8) { audio_source && audio_source != source }
      end

      def solved(attempts, transcriptions = [])
        token = wait_until(5) { page.evaluate(TOKEN_JS, @anchor.name.to_s) }
        details = { transcriptions: transcriptions.empty? ? nil : transcriptions }.compact
        Result.solved(type, token: token, attempts: attempts, message: 'reCAPTCHA solved', **details)
      end

      def blocked(**details)
        unsolved(:blocked,
                 'Google refused to serve a challenge ("Try again later": automated queries detected). ' \
                 'Wait, change IP, or use a BotBrowser / real user profile session.',
                 **details)
      end
    end
  end
end
