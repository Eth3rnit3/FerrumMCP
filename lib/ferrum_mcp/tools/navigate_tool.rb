# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Navigate to a URL
    class NavigateTool < BaseTool
      tool_name 'navigate'
      description 'Navigate to a specific URL in the browser and wait for the network to settle'

      param :url, type: :string, required: true,
                  description: 'The URL to navigate to (must include protocol: http:// or https://)'
      param :wait_for_idle, type: :boolean, default: true,
                            description: 'Wait for network idle after navigation (default: true)'
      param :timeout, type: :number, default: 30,
                      description: 'Seconds to wait for the network to become idle (default: 30)'

      def perform(params)
        ensure_browser_active
        url = params[:url].to_s

        raise ToolError, 'URL must start with http:// or https://' unless %r{\Ahttps?://}.match?(url)

        @browser_manager.config.url_policy.check!(url)

        logger.info "Navigating to: #{url}"
        page.goto(url)
        page.network.wait_for_idle(timeout: params[:timeout]) if params[:wait_for_idle]

        success_response(url: page.url, title: page.title)
      rescue Ferrum::TimeoutError => e
        logger.error "Navigation timeout: #{e.message}"
        error_response("Navigation timed out: #{e.message}")
      rescue StandardError => e
        logger.error "Navigation failed: #{e.message}"
        error_response("Failed to navigate: #{e.message}")
      end
    end
  end
end
