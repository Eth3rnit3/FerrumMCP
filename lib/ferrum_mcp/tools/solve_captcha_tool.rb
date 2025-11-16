# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to automatically detect and solve audio CAPTCHAs using Whisper
    # Works intelligently without requiring specific selectors
    # rubocop:disable Metrics/ClassLength
    class SolveCaptchaTool < BaseTool
      def self.tool_name
        'solve_captcha'
      end

      def self.description
        'Automatically detect and solve audio CAPTCHA challenges using Whisper speech recognition. ' \
          'Intelligently finds reCAPTCHA, hCaptcha, and other audio challenges without manual configuration.'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            session_id: {
              type: 'string',
              description: 'Session ID to use for this operation'
            }
          },
          required: %w[session_id]
        }
      end

      # Known CAPTCHA checkbox selectors (to trigger challenge)
      CAPTCHA_CHECKBOX_SELECTORS = [
        # reCAPTCHA
        '.recaptcha-checkbox-border',
        '#recaptcha-anchor',

        # hCaptcha
        '.h-captcha',
        '.checkbox-label'
      ].freeze

      # Known CAPTCHA audio button selectors
      AUDIO_BUTTON_SELECTORS = [
        # reCAPTCHA
        '#recaptcha-audio-button',
        'button[aria-labelledby*="audio"]',
        'button[title*="audio" i]',

        # hCaptcha
        'button[aria-label*="audio" i]',

        # Generic
        'button[id*="audio" i]',
        'button[class*="audio" i]',
        '[data-action*="audio" i]'
      ].freeze

      # Known CAPTCHA audio source selectors
      AUDIO_SOURCE_SELECTORS = [
        # reCAPTCHA
        'audio#audio-source',
        'audio source',
        '#audio-source',
        'audio',
        '.rc-audiochallenge-tdownload-link',
        'a.rc-audiochallenge-tdownload-link',
        '.rc-audiochallenge-instructions a',

        # hCaptcha
        'audio source',

        # Generic
        'audio[src]',
        '[id*="audio"][src]',
        '[id*="audio"][href]'
      ].freeze

      # Known CAPTCHA input field selectors
      INPUT_FIELD_SELECTORS = [
        # reCAPTCHA
        '#audio-response',
        'input[id*="audio"]',
        '.rc-audiochallenge-response-field',

        # hCaptcha
        'input[type="text"]',
        'input[data-action*="verify" i]',

        # Generic
        'input[placeholder*="hear" i]',
        'input[aria-label*="audio" i]'
      ].freeze

      # Known CAPTCHA verify/submit button selectors
      VERIFY_BUTTON_SELECTORS = [
        # reCAPTCHA
        '#recaptcha-verify-button',
        'button[id*="verify" i]',
        '.rc-button-default',

        # hCaptcha
        'button[type="submit"]',
        'button[data-action*="verify" i]',

        # Generic
        'button[class*="submit" i]',
        'button[value*="verify" i]'
      ].freeze

      def execute(_params)
        ensure_browser_active

        logger.info 'Starting intelligent CAPTCHA detection and solving...'

        # Initialize Whisper service
        whisper = WhisperService.new(logger: logger)

        # Wait for page to load with random delay
        random_sleep(1.5, 2.5)

        # Step 1: Click CAPTCHA checkbox to trigger challenge
        logger.info 'Detecting CAPTCHA checkbox...'
        checkbox_info = detect_and_click_checkbox
        if checkbox_info[:found]
          logger.info "Found checkbox: #{checkbox_info[:selector]}"
          random_sleep(2, 3) # Wait for challenge to appear with random delay
        else
          logger.info 'No checkbox found, assuming challenge already visible'
        end

        # Step 2: Detect CAPTCHA and click audio button
        logger.info 'Detecting CAPTCHA audio button...'
        audio_button_info = detect_and_click_audio_button
        return error_response('No CAPTCHA audio button found') unless audio_button_info[:found]

        logger.info "Found audio button: #{audio_button_info[:selector]}"

        # Wait for audio challenge to load with random delay
        random_sleep(2, 3)

        # Step 2: Detect and get audio URL
        logger.info 'Detecting audio source...'
        audio_url = detect_audio_source
        return error_response('No audio source found') unless audio_url

        logger.info "Found audio URL: #{audio_url[0..50]}..."

        # Step 3: Download audio using Whisper service
        logger.info 'Downloading audio challenge...'
        audio_file = whisper.download_audio(browser, audio_url)

        begin
          # Step 4: Transcribe with Whisper service
          logger.info 'Transcribing with Whisper...'
          transcription = whisper.transcribe(audio_file.path)
          logger.info "Transcription: #{transcription}"

          # Step 5: Detect and fill input field
          logger.info 'Detecting input field...'
          input_info = detect_and_fill_input(transcription)
          return error_response('No input field found') unless input_info[:found]

          logger.info "Filled input: #{input_info[:selector]}"

          # Step 6: Detect and click verify button
          logger.info 'Detecting verify button...'
          verify_info = detect_and_click_verify
          return error_response('No verify button found') unless verify_info[:found]

          logger.info "Clicked verify: #{verify_info[:selector]}"

          # Wait for verification with random delay
          random_sleep(1.5, 2.5)

          success_response(
            message: 'CAPTCHA solved successfully',
            transcription: transcription,
            audio_button: audio_button_info[:selector],
            input_field: input_info[:selector],
            verify_button: verify_info[:selector]
          )
        ensure
          cleanup_audio_file(audio_file)
        end
      rescue StandardError => e
        logger.error "CAPTCHA solving failed: #{e.message}"
        logger.error e.backtrace.first(5).join("\n")
        error_response("Failed to solve CAPTCHA: #{e.message}")
      end

      private

      # Detect and click CAPTCHA checkbox to trigger challenge
      def detect_and_click_checkbox
        # Try known checkbox selectors
        CAPTCHA_CHECKBOX_SELECTORS.each do |selector|
          element = browser.at_css(selector)
          next unless element
          next unless element_visible?(element)

          if click_element(element)
            logger.info "Clicked checkbox: #{selector}"
            return { found: true, selector: selector }
          end
        rescue StandardError => e
          logger.debug "Checkbox selector '#{selector}' failed: #{e.message}"
        end

        # Try in iframes
        frames = browser.frames
        if frames.length > 1
          frames[1..].each_with_index do |frame, index|
            CAPTCHA_CHECKBOX_SELECTORS.each do |selector|
              element = frame.at_css(selector)
              next unless element

              if click_element(element)
                logger.info "Clicked checkbox in iframe: #{selector}"
                return { found: true, selector: "iframe[#{index}] > #{selector}" }
              end
            rescue StandardError => e
              logger.debug "Iframe checkbox '#{selector}' failed: #{e.message}"
            end
          rescue StandardError => e
            logger.debug "Cannot access iframe #{index}: #{e.message}"
          end
        end

        { found: false }
      end

      # Detect and click audio button using multiple strategies
      def detect_and_click_audio_button
        # Strategy 1: Try known selectors
        AUDIO_BUTTON_SELECTORS.each do |selector|
          element = browser.at_css(selector)
          next unless element
          next unless element_visible?(element)

          if click_element(element)
            logger.info "Clicked audio button: #{selector}"
            return { found: true, selector: selector }
          end
        rescue StandardError => e
          logger.debug "Selector '#{selector}' failed: #{e.message}"
        end

        # Strategy 2: Try text-based detection
        audio_patterns = ['audio challenge', 'audio', 'listen', 'get an audio challenge']

        audio_patterns.each do |pattern|
          elements = find_elements_by_text(pattern, tag: 'button')
          element = elements.find { |el| element_visible?(el) }
          next unless element

          if click_element(element)
            logger.info "Clicked audio button by text: #{pattern}"
            return { found: true, selector: "button[text*='#{pattern}']" }
          end
        rescue StandardError => e
          logger.debug "Text pattern '#{pattern}' failed: #{e.message}"
        end

        # Strategy 3: Try iframes
        result = try_audio_button_in_iframes
        return result if result[:found]

        { found: false }
      end

      # Try to find audio button in iframes
      def try_audio_button_in_iframes
        frames = browser.frames
        return { found: false } if frames.length <= 1

        frames[1..].each_with_index do |frame, index|
          AUDIO_BUTTON_SELECTORS.each do |selector|
            element = frame.at_css(selector)
            next unless element

            if click_element(element)
              logger.info "Clicked audio button in iframe: #{selector}"
              return { found: true, selector: "iframe[#{index}] > #{selector}" }
            end
          rescue StandardError => e
            logger.debug "Iframe selector '#{selector}' failed: #{e.message}"
          end
        rescue StandardError => e
          logger.debug "Cannot access iframe #{index}: #{e.message}"
        end

        { found: false }
      end

      # Detect audio source URL
      def detect_audio_source
        logger.debug 'Trying to find audio source in main frame...'

        # Try known selectors
        AUDIO_SOURCE_SELECTORS.each do |selector|
          element = browser.at_css(selector)
          if element
            logger.debug "Found element with selector: #{selector}"
          else
            logger.debug "No element found for selector: #{selector}"
            next
          end

          # Try src attribute
          url = element.attribute('src') || element.property('src')
          if url && !url.empty?
            logger.info "Found audio URL via src: #{url[0..50]}..."
            return url
          end

          # Try href for download links
          url = element.attribute('href') || element.property('href')
          if url && !url.empty?
            logger.info "Found audio URL via href: #{url[0..50]}..."
            return url
          end

          logger.debug 'Element found but no src/href attribute'
        rescue StandardError => e
          logger.debug "Audio source selector '#{selector}' failed: #{e.message}"
        end

        # Try finding in iframes
        logger.debug 'Trying to find audio source in iframes...'
        frames = browser.frames
        logger.debug "Found #{frames.length} frames"

        if frames.length > 1
          frames[1..].each_with_index do |frame, index|
            logger.debug "Checking iframe #{index + 1}..."
            AUDIO_SOURCE_SELECTORS.each do |selector|
              element = frame.at_css(selector)
              if element
                logger.debug "Found element in iframe with selector: #{selector}"
                url = element.attribute('src') || element.property('src')
                if url && !url.empty?
                  logger.info "Found audio URL in iframe via src: #{url[0..50]}..."
                  return url
                end
              end
            rescue StandardError => e
              logger.debug "Iframe audio source '#{selector}' failed: #{e.message}"
            end
          rescue StandardError => e
            logger.debug "Cannot access iframe #{index + 1}: #{e.message}"
          end
        end

        logger.error 'No audio source found after trying all strategies'
        nil
      end

      # Detect and fill input field
      def detect_and_fill_input(text)
        INPUT_FIELD_SELECTORS.each do |selector|
          element = browser.at_css(selector)
          next unless element
          next unless element_visible?(element)

          with_retry do
            element.focus
            random_sleep(0.1, 0.2)
            # Type each character with small random delays to mimic human typing
            type_like_human(element, text)
          end

          logger.info "Filled input: #{selector}"
          return { found: true, selector: selector }
        rescue StandardError => e
          logger.debug "Input selector '#{selector}' failed: #{e.message}"
        end

        # Try in iframes
        frames = browser.frames
        if frames.length > 1
          frames[1..].each_with_index do |frame, index|
            INPUT_FIELD_SELECTORS.each do |selector|
              element = frame.at_css(selector)
              next unless element

              element.focus
              random_sleep(0.1, 0.2)
              type_like_human(element, text)

              logger.info "Filled input in iframe: #{selector}"
              return { found: true, selector: "iframe[#{index}] > #{selector}" }
            rescue StandardError => e
              logger.debug "Iframe input '#{selector}' failed: #{e.message}"
            end
          rescue StandardError
            nil
          end
        end

        { found: false }
      end

      # Detect and click verify button
      def detect_and_click_verify
        VERIFY_BUTTON_SELECTORS.each do |selector|
          element = browser.at_css(selector)
          next unless element
          next unless element_visible?(element)

          if click_element(element)
            logger.info "Clicked verify: #{selector}"
            return { found: true, selector: selector }
          end
        rescue StandardError => e
          logger.debug "Verify selector '#{selector}' failed: #{e.message}"
        end

        # Try text-based detection
        verify_patterns = %w[verify submit check]
        verify_patterns.each do |pattern|
          elements = find_elements_by_text(pattern, tag: 'button')
          element = elements.find { |el| element_visible?(el) }
          next unless element

          if click_element(element)
            logger.info "Clicked verify by text: #{pattern}"
            return { found: true, selector: "button[text*='#{pattern}']" }
          end
        rescue StandardError => e
          logger.debug "Verify pattern '#{pattern}' failed: #{e.message}"
        end

        # Try in iframes
        frames = browser.frames
        if frames.length > 1
          frames[1..].each_with_index do |frame, index|
            VERIFY_BUTTON_SELECTORS.each do |selector|
              element = frame.at_css(selector)
              next unless element

              if click_element(element)
                logger.info "Clicked verify in iframe: #{selector}"
                return { found: true, selector: "iframe[#{index}] > #{selector}" }
              end
            rescue StandardError => e
              logger.debug "Iframe verify '#{selector}' failed: #{e.message}"
            end
          rescue StandardError
            nil
          end
        end

        { found: false }
      end

      # Helper: Find elements by text
      def find_elements_by_text(text, tag: '*')
        escaped = escape_xpath_string(text)
        xpath = "//#{tag}[contains(translate(normalize-space(.), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', " \
                "'abcdefghijklmnopqrstuvwxyz'), #{escaped})]"

        browser.xpath(xpath)
      rescue StandardError => e
        logger.debug "XPath search for '#{text}' failed: #{e.message}"
        []
      end

      # Helper: Escape XPath string
      def escape_xpath_string(text)
        return "'#{text.downcase}'" unless text.include?("'")

        parts = text.downcase.split("'")
        quoted_parts = parts.map { |part| "'#{part}'" }
        "concat(#{quoted_parts.join(", \"'\", ")})"
      end

      # Helper: Random sleep to mimic human behavior
      def random_sleep(min, max)
        sleep(rand(min..max))
      end

      # Helper: Type text like a human with random delays between characters
      def type_like_human(element, text)
        text.each_char do |char|
          element.type(char)
          sleep(rand(0.05..0.15)) # Random delay between keystrokes
        end
      end

      # Helper: Click element with fallback and human-like delay
      def click_element(element)
        return false unless element

        element.scroll_into_view if element.respond_to?(:scroll_into_view)
        random_sleep(0.1, 0.3) # Random delay before click
        element.click
        random_sleep(0.2, 0.4) # Random delay after click
        true
      rescue StandardError => e
        logger.debug "Native click failed: #{e.message}, trying JavaScript..."

        begin
          browser.execute(<<~JAVASCRIPT, element)
            arguments[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
            setTimeout(() => arguments[0].click(), 100);
          JAVASCRIPT
          random_sleep(0.3, 0.5)
          true
        rescue StandardError => js_error
          logger.debug "JavaScript click failed: #{js_error.message}"
          false
        end
      end

      # Helper: Cleanup temp file
      def cleanup_audio_file(temp_file)
        return unless temp_file

        temp_file.close unless temp_file.closed?
        temp_file.unlink
        logger.debug 'Audio file cleaned up'
      rescue StandardError => e
        logger.warn "Cleanup failed: #{e.message}"
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
