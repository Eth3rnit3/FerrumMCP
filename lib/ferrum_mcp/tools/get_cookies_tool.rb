# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Get cookies
    class GetCookiesTool < BaseTool
      tool_name 'get_cookies'
      description 'Get all cookies or the cookies whose domain contains the given string'

      param :domain, type: :string, description: 'Optional: filter cookies by domain (substring match)'

      def perform(params)
        ensure_browser_active
        domain = params[:domain]
        logger.info "Getting cookies#{" for #{domain}" if domain}"

        cookies = page.cookies.all.map { |name, cookie| cookie_to_hash(name, cookie) }
        cookies.select! { |c| c[:domain].to_s.include?(domain) } if domain

        success_response(cookies: cookies, count: cookies.length)
      end

      private

      def cookie_to_hash(name, cookie)
        return { name: name, value: cookie.to_s } unless cookie.respond_to?(:attributes)

        attrs = cookie.attributes
        {
          name: cookie.name || name, value: cookie.value, domain: cookie.domain, path: cookie.path,
          expires: cookie.expires&.iso8601, size: cookie.size, secure: cookie.secure?,
          httponly: cookie.httponly?, session: cookie.session?, samesite: cookie.samesite,
          priority: attrs['priority']
        }.compact
      end
    end
  end
end
