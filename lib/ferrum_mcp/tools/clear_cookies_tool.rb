# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Clear cookies
    class ClearCookiesTool < BaseTool
      tool_name 'clear_cookies'
      description 'Clear all cookies, or only the cookies whose domain contains the given string'

      param :domain, type: :string, description: 'Optional: clear cookies only for this domain (substring match)'

      def perform(params)
        ensure_browser_active
        domain = params[:domain]

        if domain
          logger.info "Clearing cookies for: #{domain}"
          removed = 0
          page.cookies.all.each_value do |cookie|
            next unless cookie.respond_to?(:domain) && cookie.domain.to_s.include?(domain)

            page.cookies.remove(name: cookie.name, domain: cookie.domain, path: cookie.path)
            removed += 1
          end
          success_response(message: "Cleared #{removed} cookies for #{domain}", count: removed)
        else
          logger.info 'Clearing all cookies'
          page.cookies.clear
          success_response(message: 'All cookies cleared')
        end
      rescue StandardError => e
        logger.error "Clear cookies failed: #{e.message}"
        error_response("Failed to clear cookies: #{e.message}")
      end
    end
  end
end
