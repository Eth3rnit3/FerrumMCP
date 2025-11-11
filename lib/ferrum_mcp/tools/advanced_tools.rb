# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to execute JavaScript code
    class ExecuteScriptTool < BaseTool
      def self.tool_name
        'execute_script'
      end

      def self.description
        'Execute JavaScript code in the browser context'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            script: {
              type: 'string',
              description: 'JavaScript code to execute'
            }
          },
          required: ['script']
        }
      end

      def execute(params)
        ensure_browser_active
        script = params['script'] || params[:script]

        logger.info 'Executing JavaScript'
        browser.execute(script)

        success_response(message: 'Script executed successfully')
      rescue StandardError => e
        logger.error "Execute script failed: #{e.message}"
        error_response("Failed to execute script: #{e.message}")
      end
    end

    # Tool to evaluate JavaScript and return result
    class EvaluateJSTool < BaseTool
      def self.tool_name
        'evaluate_js'
      end

      def self.description
        'Evaluate JavaScript expression and return the result'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            expression: {
              type: 'string',
              description: 'JavaScript expression to evaluate'
            }
          },
          required: ['expression']
        }
      end

      def execute(params)
        ensure_browser_active
        expression = params['expression'] || params[:expression]

        logger.info 'Evaluating JavaScript'
        result = browser.evaluate(expression)

        success_response(result: result)
      rescue StandardError => e
        logger.error "Evaluate JS failed: #{e.message}"
        error_response("Failed to evaluate JS: #{e.message}")
      end
    end

    # Tool to get cookies
    class GetCookiesTool < BaseTool
      def self.tool_name
        'get_cookies'
      end

      def self.description
        'Get all cookies or cookies for a specific domain'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            domain: {
              type: 'string',
              description: 'Optional: Filter cookies by domain'
            }
          }
        }
      end

      def execute(params)
        ensure_browser_active
        domain = params['domain'] || params[:domain]

        logger.info "Getting cookies#{domain ? " for #{domain}" : ''}"
        all_cookies = browser.cookies.all

        # Convert cookies to hash format
        # cookies.all returns a hash where values can be Cookie objects or strings
        cookies_hash = {}
        all_cookies.each do |name, cookie|
          cookie_str = cookie.is_a?(String) ? cookie : cookie.to_s
          cookies_hash[name] = cookie_str
        end

        # Filter by domain if specified
        if domain
          cookies_hash = cookies_hash.select do |_name, cookie_string|
            cookie_string && cookie_string.match(/Domain=([^;]+)/i) &&
            Regexp.last_match(1).include?(domain)
          end
        end

        success_response(
          cookies: cookies_hash,
          count: cookies_hash.length
        )
      rescue StandardError => e
        logger.error "Get cookies failed: #{e.message}"
        error_response("Failed to get cookies: #{e.message}")
      end
    end

    # Tool to set a cookie
    class SetCookieTool < BaseTool
      def self.tool_name
        'set_cookie'
      end

      def self.description
        'Set a cookie in the browser'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            name: {
              type: 'string',
              description: 'Cookie name'
            },
            value: {
              type: 'string',
              description: 'Cookie value'
            },
            domain: {
              type: 'string',
              description: 'Cookie domain'
            },
            path: {
              type: 'string',
              description: 'Cookie path (default: /)',
              default: '/'
            },
            secure: {
              type: 'boolean',
              description: 'Secure flag (default: false)',
              default: false
            },
            httponly: {
              type: 'boolean',
              description: 'HttpOnly flag (default: false)',
              default: false
            }
          },
          required: %w[name value domain]
        }
      end

      def execute(params)
        ensure_browser_active

        cookie = {
          name: params['name'] || params[:name],
          value: params['value'] || params[:value],
          domain: params['domain'] || params[:domain],
          path: params['path'] || params[:path] || '/',
          secure: params['secure'] || params[:secure] || false,
          httpOnly: params['httponly'] || params[:httponly] || false
        }

        logger.info "Setting cookie: #{cookie[:name]}"
        browser.cookies.set(**cookie)

        success_response(message: "Cookie set: #{cookie[:name]}")
      rescue StandardError => e
        logger.error "Set cookie failed: #{e.message}"
        error_response("Failed to set cookie: #{e.message}")
      end
    end

    # Tool to clear cookies
    class ClearCookiesTool < BaseTool
      def self.tool_name
        'clear_cookies'
      end

      def self.description
        'Clear all cookies or cookies for a specific domain'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            domain: {
              type: 'string',
              description: 'Optional: Clear cookies only for this domain'
            }
          }
        }
      end

      def execute(params)
        ensure_browser_active
        domain = params['domain'] || params[:domain]

        if domain
          logger.info "Clearing cookies for: #{domain}"
          # cookies.all returns a hash where keys are cookie names and values can be Cookie objects or strings
          all_cookies = browser.cookies.all
          cookies_to_remove = all_cookies.select do |_name, cookie|
            cookie_str = cookie.is_a?(String) ? cookie : cookie.to_s
            cookie_str && cookie_str.match(/Domain=([^;]+)/i) &&
            Regexp.last_match(1).include?(domain)
          end
          # Remove each cookie by name with domain
          cookies_to_remove.each do |cookie_name, cookie|
            # Extract domain from cookie string
            cookie_str = cookie.is_a?(String) ? cookie : cookie.to_s
            if cookie_str.match(/Domain=([^;]+)/i)
              cookie_domain = Regexp.last_match(1).strip
              browser.cookies.remove(name: cookie_name, domain: cookie_domain)
            end
          end
          success_response(message: "Cleared #{cookies_to_remove.length} cookies for #{domain}")
        else
          logger.info 'Clearing all cookies'
          browser.cookies.clear
          success_response(message: 'All cookies cleared')
        end
      rescue StandardError => e
        logger.error "Clear cookies failed: #{e.message}"
        error_response("Failed to clear cookies: #{e.message}")
      end
    end

    # Tool to get element attributes
    class GetAttributeTool < BaseTool
      def self.tool_name
        'get_attribute'
      end

      def self.description
        'Get attribute value(s) from an element'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            selector: {
              type: 'string',
              description: 'CSS selector of the element'
            },
            attribute: {
              type: 'string',
              description: 'Attribute name to get'
            }
          },
          required: %w[selector attribute]
        }
      end

      def execute(params)
        ensure_browser_active
        selector = params['selector'] || params[:selector]
        attribute = params['attribute'] || params[:attribute]

        logger.info "Getting attribute '#{attribute}' from: #{selector}"
        element = find_element(selector)
        value = element.attribute(attribute)

        success_response(
          selector: selector,
          attribute: attribute,
          value: value
        )
      rescue StandardError => e
        logger.error "Get attribute failed: #{e.message}"
        error_response("Failed to get attribute: #{e.message}")
      end
    end
  end
end
