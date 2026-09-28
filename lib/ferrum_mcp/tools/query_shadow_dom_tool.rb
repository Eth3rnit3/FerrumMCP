# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Interact with Shadow DOM elements
    class QueryShadowDOMTool < BaseTool
      tool_name 'query_shadow_dom'
      description 'Query and interact with elements inside a Shadow DOM'

      param :host_selector, type: :string, required: true, description: 'CSS selector of the Shadow DOM host element'
      param :shadow_selector, type: :string, required: true,
                              description: 'CSS selector to find element(s) within the Shadow DOM'
      param :action, type: :string, required: true, enum: %w[click get_text get_html get_attribute],
                     description: 'Action to perform: click, get_text, get_html, or get_attribute'
      param :attribute, type: :string, description: 'Attribute name (required when action is get_attribute)'
      param :multiple, type: :boolean, default: false, description: 'Return all matching elements (default: false)'

      def perform(params)
        action = params[:action]
        logger.info "Querying Shadow DOM: #{params[:host_selector]} -> #{params[:shadow_selector]}, action: #{action}"

        if action == 'get_attribute' && params[:attribute].to_s.empty?
          raise ToolError, 'attribute parameter required for get_attribute action'
        end

        result = page.evaluate(script_for(action, params[:multiple]),
                               params[:host_selector], params[:shadow_selector], params[:attribute])
        success_response(format_result(action, params, result))
      rescue StandardError => e
        logger.error "Shadow DOM query failed: #{e.message}"
        error_response("Failed to query Shadow DOM: #{e.message}")
      end

      EXTRACTORS = {
        'click' => 'el.scrollIntoView({ behavior: "instant", block: "center" }); el.click(); return true;',
        'get_text' => 'return el.textContent;',
        'get_html' => 'return el.innerHTML;',
        'get_attribute' => 'return el.getAttribute(attribute);'
      }.freeze

      private

      def script_for(action, multiple)
        extractor = EXTRACTORS.fetch(action) { raise ToolError, "Unknown action: #{action}" }
        <<~JS
          (function(hostSelector, shadowSelector, attribute) {
            const host = document.querySelector(hostSelector);
            if (!host || !host.shadowRoot) throw new Error('Shadow DOM host not found or has no shadowRoot');
            const extract = (el) => { #{extractor} };
            if (#{multiple ? 'true' : 'false'}) {
              return Array.from(host.shadowRoot.querySelectorAll(shadowSelector)).map(extract);
            }
            const el = host.shadowRoot.querySelector(shadowSelector);
            if (!el) throw new Error('Element not found in Shadow DOM');
            return extract(el);
          })(arguments[0], arguments[1], arguments[2])
        JS
      end

      def format_result(action, params, result)
        case action
        when 'click' then { message: "Clicked element in Shadow DOM: #{params[:shadow_selector]}" }
        when 'get_text' then params[:multiple] ? { texts: result, count: result.length } : { text: result }
        when 'get_html' then params[:multiple] ? { html: result, count: result.length } : { html: result }
        else params[:multiple] ? { values: result, count: result.length } : { value: result }
        end
      end
    end
  end
end
