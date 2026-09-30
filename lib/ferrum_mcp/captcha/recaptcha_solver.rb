# frozen_string_literal: true

require 'base64'
require 'digest'
require 'fileutils'

module FerrumMCP
  module Captcha
    # reCAPTCHA v2 (checkbox, invisible, enterprise) through the audio challenge.
    #
    # The widget is made of two iframes sharing a suffix: the anchor ("a-XYZ",
    # the checkbox) and the challenge frame ("c-XYZ", bframe). Google often asks
    # for several correct answers in a row, so the solver loops until the anchor
    # reports aria-checked="true", then reads the token from the host page.
    class RecaptchaSolver < BaseSolver
      include RecaptchaScripts

      BFRAME = %r{/recaptcha/(?:api2|enterprise)/bframe}
      DEFAULT_ATTEMPTS = 5
      MAX_GARBLED_IN_A_ROW = 2
      WARM_UP_SECONDS = (3.0..6.0)
      MIN_AUDIO_BYTES = 16_000 # a full challenge is ~30 KB
      AUDIO_DOWNLOADS = 3
      AUDIO_RETRY_DELAY = 1

      # Phrases whisper produces on audio it cannot understand (it was trained
      # on subtitled videos). Real challenges are short everyday sentences.
      HALLUCINATIONS = [
        /\Asee you (next time|soon)\z/,
        /thanks? (you )?(so much )?for watching/,
        /\A(i'm not sure ?)+\z/,
        /subscribe|like and share/,
        /gracias por ver|obrigado por assistir|merci d'avoir regard/
      ].freeze

      # Every distrusted session receives the same unintelligible ~4 s clip.
      # Its fingerprint gives the verdict at once: no Whisper run, no reload.
      KNOWN_DECOY_MD5S = %w[18028cdcb77a664d5ab15adb489d1bf8].freeze

      def self.known_decoy?(audio)
        KNOWN_DECOY_MD5S.include?(Digest::MD5.hexdigest(audio))
      end

      # Unintelligible audio: reCAPTCHA serves it to clients it distrusts.
      # Answering it only lowers the IP's reputation, so ask for another one.
      def self.garbled?(transcription, expected_language)
        text = transcription.text.to_s
        return true if text.empty? || HALLUCINATIONS.any? { |pattern| text.match?(pattern) }
        return false if expected_language.to_s == 'auto' || transcription.language.nil?

        transcription.language != expected_language.to_s
      end

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
        frame_url(frame).include?('size=invisible')
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
          progress(0, max_attempts, 'invisible widget, calling grecaptcha.execute()')
          page.evaluate(EXECUTE_INVISIBLE_JS)
        else
          progress(0, max_attempts, 'moving over the page, then clicking the checkbox')
          warm_up(rand(WARM_UP_SECONDS))
          human_click_node(@anchor.at_css('#recaptcha-anchor'))
        end
      end

      def switch_to_audio
        logger.info 'reCAPTCHA: switching to the audio challenge'
        pause(1.5, 3.5) # looking at the image grid
        human_click_node(challenge_frame.at_css('#recaptcha-audio-button'))
        wait_until(8) { %w[audio blocked].include?(current_challenge) }
      end

      def solve_audio_rounds
        @transcriptions = []
        garbled_in_a_row = 0

        max_attempts.times do |round|
          return blocked(attempts: round, transcriptions: @transcriptions) if current_challenge == 'blocked'
          return solved(round, @transcriptions) if checked?

          source = audio_source
          return unsolved(:failed, 'reCAPTCHA audio challenge not available', attempts: round) unless source

          progress(round + 1, max_attempts, "audio round #{round + 1}/#{max_attempts}: transcribing")
          audio = download_audio(source)
          return known_decoy(round + 1) if self.class.known_decoy?(audio)

          heard = listen(audio, round)
          garbled_in_a_row = heard ? 0 : garbled_in_a_row + 1
          return distrusted(round + 1, @transcriptions) if garbled_in_a_row >= MAX_GARBLED_IN_A_ROW

          result = answer_round(heard, source, round)
          return result if result
        end

        unsolved(:failed, "reCAPTCHA not solved after #{max_attempts} audio challenges",
                 attempts: max_attempts, transcriptions: @transcriptions)
      end

      def known_decoy(attempts)
        logger.info 'reCAPTCHA: known decoy audio served'
        @transcriptions << '(known decoy audio)'
        distrusted(attempts, @transcriptions)
      end

      # Transcribed answer, or nil when the audio is garbled
      def listen(audio, round)
        heard = transcribe(audio)
        garbled = self.class.garbled?(heard, expected_language)
        @transcriptions << (garbled ? "(garbled #{heard.language}) #{heard.text}" : heard.text)
        logger.info "reCAPTCHA: round #{round + 1} heard #{heard.text.inspect} " \
                    "[#{heard.language} #{heard.language_probability}]#{' -> garbled' if garbled}"
        garbled ? nil : heard.text
      end

      # Final Result, or nil to play another round
      def answer_round(answer, source, round)
        case answer ? submit_answer(answer, source) : :reload
        when :solved then solved(round + 1, @transcriptions)
        when :blocked then blocked(attempts: round + 1, transcriptions: @transcriptions)
        when :reload then reload_challenge(source) && nil
        end
      end

      def audio_source
        challenge_frame&.evaluate("(document.querySelector('#audio-source') || {}).src || null")
      end

      def transcribe(audio)
        transcriber.analyze_bytes(audio).tap { |heard| keep_sample(audio, heard) }
      end

      # Fetched right after the challenge appears, the payload can come back
      # cut short (8 KB of a ~30 KB clip). Download again and keep the largest.
      def download_audio(source)
        downloads = []
        AUDIO_DOWNLOADS.times do |attempt|
          sleep AUDIO_RETRY_DELAY if attempt.positive?
          encoded = challenge_frame.evaluate_async(FETCH_AUDIO_JS, 20, source)
          downloads << Base64.decode64(encoded) if encoded
          break if downloads.last.to_s.bytesize >= MIN_AUDIO_BYTES
        end
        raise ToolError, 'Could not download the reCAPTCHA audio' if downloads.empty?

        downloads.max_by(&:bytesize)
      end

      def expected_language
        options[:language] || ENV.fetch('WHISPER_LANGUAGE', 'en')
      end

      # CAPTCHA_AUDIO_DIR: keep every challenge audio and what was heard, to
      # study failures and tune the garbled-audio detection.
      def keep_sample(audio, heard)
        dir = ENV.fetch('CAPTCHA_AUDIO_DIR', nil)
        return unless dir

        FileUtils.mkdir_p(dir)
        base = File.join(dir, "recaptcha-#{Time.now.strftime('%Y%m%d-%H%M%S-%L')}")
        File.binwrite("#{base}.mp3", audio)
        File.write("#{base}.json", JSON.generate(heard.to_h))
      rescue StandardError => e
        logger.debug "keep_sample failed: #{e.message}"
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

      def distrusted(attempts, transcriptions)
        unsolved(:distrusted,
                 'reCAPTCHA only serves its decoy audio: this browser session is not trusted. Stopped early ' \
                 'to protect the IP. Retry later, from another IP, or with a browser profile that has history.',
                 attempts: attempts, transcriptions: transcriptions)
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
