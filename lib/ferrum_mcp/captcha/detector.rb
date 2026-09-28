# frozen_string_literal: true

module FerrumMCP
  module Captcha
    # Finds CAPTCHA widgets on a page by the URL of the frames they load.
    # Frame URLs are stable across site integrations, unlike host-page markup.
    module Detector
      FRAME_PATTERNS = {
        recaptcha: %r{\Ahttps://(?:www\.)?(?:google\.com|recaptcha\.net)/recaptcha/(?:api2|enterprise)/anchor},
        hcaptcha: %r{\Ahttps://[^/]*hcaptcha\.com/.*#frame=checkbox},
        turnstile: %r{\Ahttps://challenges\.cloudflare\.com/}
      }.freeze

      SOLVERS = {
        recaptcha: 'RecaptchaSolver',
        hcaptcha: 'HcaptchaSolver',
        turnstile: 'TurnstileSolver'
      }.freeze

      module_function

      # @return [Array<Symbol>] CAPTCHA types present, in FRAME_PATTERNS order
      def detect(page)
        urls = page.frames.map { |frame| frame.url.to_s }
        types_for_urls(urls)
      end

      def types_for_urls(urls)
        FRAME_PATTERNS.select { |_type, pattern| urls.any? { |url| url.match?(pattern) } }.keys
      end

      def solver_class(type)
        Captcha.const_get(SOLVERS.fetch(type.to_sym))
      end
    end
  end
end
