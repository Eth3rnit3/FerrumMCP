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
        urls = frame_urls(page).values + iframes(page).map { |iframe| iframe[:src] }
        types_for_urls(urls)
      end

      # See FrameTree: Ferrum's Frame#url can wait minutes on stale frames
      def frame_urls(page)
        FrameTree.urls(page)
      end

      # Every <iframe> of the page, including those behind closed shadow roots
      # and out-of-process ones, which Ferrum's page.frames does not list.
      # @return [Array<Hash>] { src:, backend_node_id: }
      def iframes(page)
        root = page.command('DOM.getDocument', depth: -1, pierce: true)['root']
        walk(root).filter_map do |node|
          next unless node['nodeName'] == 'IFRAME'

          attributes = node['attributes'].to_a.each_slice(2).to_h
          { src: attributes['src'].to_s, backend_node_id: node['backendNodeId'] }
        end
      rescue StandardError
        []
      end

      def walk(node)
        children = node['children'].to_a + node['shadowRoots'].to_a
        children << node['contentDocument'] if node['contentDocument']
        [node] + children.flat_map { |child| walk(child) }
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
