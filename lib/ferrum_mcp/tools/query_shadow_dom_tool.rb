# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to interact with Shadow DOM elements
    class QueryShadowDOMTool < BaseTool
      def self.tool_name
        'query_shadow_dom'
      end

      def self.description
        'Query and interact with elements inside Shadow DOM'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            host_selector: {
              type: 'string',
              description: 'CSS selector of the Shadow DOM host element'
            },
            shadow_selector: {
              type: 'string',
              description: 'CSS selector to find element(s) within the Shadow DOM'
            },
            action: {
              type: 'string',
              description: 'Action to perform: click, get_text, get_html, or get_attribute',
              enum: %w[click get_text get_html get_attribute]
            },
            attribute: {
              type: 'string',
              description: 'Attribute name (required when action is get_attribute)'
            },
            multiple: {
              type: 'boolean',
              description: 'Return all matching elements (default: false)',
              default: false
            },
            session_id: {
              type: 'string',
              description: 'Session ID to use for this operation'
            }
          },
          required: %w[host_selector shadow_selector action session_id]
        }
      end

      def execute(params)
        host_selector = params['host_selector'] || params[:host_selector]
        shadow_selector = params['shadow_selector'] || params[:shadow_selector]
        action = params['action'] || params[:action]
        attribute = params['attribute'] || params[:attribute]
        multiple = params['multiple'] || params[:multiple] || false

        logger.info "Querying Shadow DOM: #{host_selector} -> #{shadow_selector}, action: #{action}"

        result = case action
                 when 'click'
                   click_in_shadow_dom(host_selector, shadow_selector)
                 when 'get_text'
                   get_text_from_shadow_dom(host_selector, shadow_selector, multiple)
                 when 'get_html'
                   get_html_from_shadow_dom(host_selector, shadow_selector, multiple)
                 when 'get_attribute'
                   raise ToolError, 'attribute parameter required for get_attribute action' unless attribute

                   get_attribute_from_shadow_dom(host_selector, shadow_selector, attribute, multiple)
                 else
                   raise ToolError, "Unknown action: #{action}"
                 end

        success_response(result)
      rescue StandardError => e
        logger.error "Shadow DOM query failed: #{e.message}"
        error_response("Failed to query Shadow DOM: #{e.message}")
      end

      private

      def click_in_shadow_dom(host_selector, shadow_selector)
        host_js = host_selector.inspect
        shadow_js = shadow_selector.inspect

        script = <<~JS.strip
          (function() {
            var host = document.querySelector(#{host_js});
            if (!host || !host.shadowRoot) {
              throw new Error('Shadow DOM host not found or has no shadowRoot');
            }
            var element = host.shadowRoot.querySelector(#{shadow_js});
            if (!element) {
              throw new Error('Element not found in Shadow DOM');
            }
            element.scrollIntoView({ behavior: 'instant', block: 'center' });
            element.click();
            return true;
          })()
        JS

        browser.execute(script)
        { message: "Clicked element in Shadow DOM: #{shadow_selector}" }
      end

      def get_text_from_shadow_dom(host_selector, shadow_selector, multiple)
        host_js = host_selector.inspect
        shadow_js = shadow_selector.inspect

        script = if multiple
                   <<~JS.strip
                     (function() {
                       var host = document.querySelector(#{host_js});
                       if (!host || !host.shadowRoot) {
                         throw new Error('Shadow DOM host not found or has no shadowRoot');
                       }
                       var elements = Array.from(host.shadowRoot.querySelectorAll(#{shadow_js}));
                       var texts = [];
                       for (var i = 0; i < elements.length; i++) {
                         texts.push(elements[i].textContent);
                       }
                       return texts;
                     })()
                   JS
                 else
                   <<~JS.strip
                     (function() {
                       var host = document.querySelector(#{host_js});
                       if (!host || !host.shadowRoot) {
                         throw new Error('Shadow DOM host not found or has no shadowRoot');
                       }
                       var element = host.shadowRoot.querySelector(#{shadow_js});
                       if (!element) {
                         throw new Error('Element not found in Shadow DOM');
                       }
                       return element.textContent;
                     })()
                   JS
                 end

        result = browser.evaluate(script)
        multiple ? { texts: result, count: result.length } : { text: result }
      end

      def get_html_from_shadow_dom(host_selector, shadow_selector, multiple)
        host_js = host_selector.inspect
        shadow_js = shadow_selector.inspect

        script = if multiple
                   <<~JS.strip
                     (function() {
                       var host = document.querySelector(#{host_js});
                       if (!host || !host.shadowRoot) {
                         throw new Error('Shadow DOM host not found or has no shadowRoot');
                       }
                       var elements = Array.from(host.shadowRoot.querySelectorAll(#{shadow_js}));
                       var htmls = [];
                       for (var i = 0; i < elements.length; i++) {
                         htmls.push(elements[i].innerHTML);
                       }
                       return htmls;
                     })()
                   JS
                 else
                   <<~JS.strip
                     (function() {
                       var host = document.querySelector(#{host_js});
                       if (!host || !host.shadowRoot) {
                         throw new Error('Shadow DOM host not found or has no shadowRoot');
                       }
                       var element = host.shadowRoot.querySelector(#{shadow_js});
                       if (!element) {
                         throw new Error('Element not found in Shadow DOM');
                       }
                       return element.innerHTML;
                     })()
                   JS
                 end

        result = browser.evaluate(script)
        multiple ? { html: result, count: result.length } : { html: result }
      end

      def get_attribute_from_shadow_dom(host_selector, shadow_selector, attribute, multiple)
        host_js = host_selector.inspect
        shadow_js = shadow_selector.inspect
        attr_js = attribute.inspect

        script = if multiple
                   <<~JS.strip
                     (function() {
                       var host = document.querySelector(#{host_js});
                       if (!host || !host.shadowRoot) {
                         throw new Error('Shadow DOM host not found or has no shadowRoot');
                       }
                       var elements = Array.from(host.shadowRoot.querySelectorAll(#{shadow_js}));
                       var values = [];
                       for (var i = 0; i < elements.length; i++) {
                         values.push(elements[i].getAttribute(#{attr_js}));
                       }
                       return values;
                     })()
                   JS
                 else
                   <<~JS.strip
                     (function() {
                       var host = document.querySelector(#{host_js});
                       if (!host || !host.shadowRoot) {
                         throw new Error('Shadow DOM host not found or has no shadowRoot');
                       }
                       var element = host.shadowRoot.querySelector(#{shadow_js});
                       if (!element) {
                         throw new Error('Element not found in Shadow DOM');
                       }
                       return element.getAttribute(#{attr_js});
                     })()
                   JS
                 end

        result = browser.evaluate(script)
        multiple ? { values: result, count: result.length } : { value: result }
      end
    end
  end
end
