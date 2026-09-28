# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Detect and solve the CAPTCHA widget on the current page.
    #
    # Detection relies on the frames the widgets load (see Captcha::Detector),
    # never on host-page markup, so the tool cannot click or type into the
    # site's own forms. Success is only reported once the provider confirms it.
    class SolveCaptchaTool < BaseTool
      TYPES = %w[auto recaptcha hcaptcha turnstile].freeze
      DETECTION_TIMEOUT = 5

      tool_name 'solve_captcha'
      description 'Detect and solve the CAPTCHA on the current page. reCAPTCHA v2 (checkbox, invisible, ' \
                  'enterprise) is solved through its audio challenge with local Whisper speech recognition; ' \
                  'Cloudflare Turnstile (widget and "Just a moment" page) and the hCaptcha checkbox are passed with ' \
                  'human-like clicks. Returns the token on success; fails with an explicit status (blocked, distrusted, ' \
                  'challenge_required, failed) otherwise.'

      param :type, type: :string, enum: TYPES, default: 'auto',
                   description: 'CAPTCHA to solve (default: auto-detect)'
      param :max_attempts, type: :integer, default: 5,
                           description: 'Maximum challenges to answer before giving up (default: 5)'
      param :language, type: :string,
                       description: 'Audio language for Whisper, e.g. "en" or "auto" (default: WHISPER_LANGUAGE or en)'

      def perform(params)
        ensure_browser_active

        type = resolve_type(params[:type])
        return error_response(not_found_message(params[:type])) unless type

        logger.info "solve_captcha: solving #{type}"
        solver = Captcha::Detector.solver_class(type).new(
          page, logger: logger, max_attempts: params[:max_attempts].to_i.clamp(1, 10),
                language: params[:language]
        )
        respond(solver.solve)
      rescue ToolError => e
        error_response("Failed to solve CAPTCHA: #{e.message}")
      rescue StandardError => e
        logger.error "solve_captcha: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        error_response("Failed to solve CAPTCHA: #{e.class}: #{e.message}")
      end

      private

      # Widgets load asynchronously, so give them a moment to appear.
      def resolve_type(requested)
        deadline = monotonic_now + DETECTION_TIMEOUT
        loop do
          detected = Captcha::Detector.detect(page)
          return detected.first if requested == 'auto' && detected.any?
          return requested.to_sym if detected.include?(requested.to_sym)
          return nil if monotonic_now > deadline

          sleep 0.5
        end
      end

      def not_found_message(requested)
        what = requested == 'auto' ? 'No supported CAPTCHA' : "No #{requested} CAPTCHA"
        "#{what} found on the page (supported: reCAPTCHA v2, hCaptcha, Cloudflare Turnstile)"
      end

      def respond(result)
        data = result.to_h
        screenshot = data.delete(:screenshot)
        return success_response(data) if result.solved?

        response = error_response("CAPTCHA not solved (#{result.type}, #{result.status}): #{result.message}")
        response[:image] = screenshot if screenshot
        response
      end
    end
  end
end
