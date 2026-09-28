# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Get HTML content
    class GetHTMLTool < BaseTool
      tool_name 'get_html'
      description 'Get HTML content of the page or of a specific element'

      param :selector, type: :string, description: 'Optional: selector of the element to get the outerHTML of'
      param :max_length, type: :integer,
                         description: 'Optional: truncate the HTML to this many characters (default: no limit)'

      def perform(params)
        ensure_browser_active
        selector = params[:selector]

        html, extra = if selector
                        logger.info "Getting HTML of element: #{selector}"
                        [find_element(selector).property('outerHTML'), { selector: selector }]
                      else
                        logger.info 'Getting page HTML'
                        [page.body, { url: page.url }]
                      end

        truncated = false
        if params[:max_length] && html.length > params[:max_length]
          html = html[0, params[:max_length]]
          truncated = true
        end

        success_response({ html: html, length: html.length, truncated: truncated }.merge(extra))
      rescue StandardError => e
        logger.error "Get HTML failed: #{e.message}"
        error_response("Failed to get HTML: #{e.message}")
      end
    end
  end
end
