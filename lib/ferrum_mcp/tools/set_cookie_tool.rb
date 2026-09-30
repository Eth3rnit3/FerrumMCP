# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Set a cookie
    class SetCookieTool < BaseTool
      tool_name 'set_cookie'
      description 'Set a cookie in the browser'

      param :name, type: :string, required: true, description: 'Cookie name'
      param :value, type: :string, required: true, description: 'Cookie value'
      param :domain, type: :string, required: true, description: 'Cookie domain'
      param :path, type: :string, default: '/', description: 'Cookie path (default: /)'
      param :secure, type: :boolean, default: false, description: 'Secure flag (default: false)'
      param :httponly, type: :boolean, default: false, description: 'HttpOnly flag (default: false)'
      param :expires, type: :integer, description: 'Optional: expiry as a Unix timestamp (seconds)'

      def perform(params)
        ensure_browser_active
        cookie = {
          name: params[:name], value: params[:value].to_s, domain: params[:domain], path: params[:path],
          secure: params[:secure], httponly: params[:httponly]
        }
        cookie[:expires] = params[:expires] if params[:expires]

        logger.info "Setting cookie: #{cookie[:name]}"
        page.cookies.set(**cookie)

        success_response(message: "Cookie set: #{cookie[:name]}")
      end
    end
  end
end
