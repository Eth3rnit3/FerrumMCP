# frozen_string_literal: true

require 'base64'

module FerrumMCP
  module Tools
    # Tool to extract text from elements
    class GetTextTool < BaseTool
      def self.tool_name
        'get_text'
      end

      def self.description
        'Extract text content from one or more elements'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            selector: {
              type: 'string',
              description: 'CSS selector of element(s) to extract text from'
            },
            multiple: {
              type: 'boolean',
              description: 'Extract from all matching elements (default: false)',
              default: false
            }
          },
          required: ['selector']
        }
      end

      def execute(params)
        ensure_browser_active
        selector = params['selector'] || params[:selector]
        multiple = params['multiple'] || params[:multiple] || false

        logger.info "Extracting text from: #{selector}"

        if multiple
          elements = browser.css(selector)
          texts = elements.map(&:text)
          success_response(texts: texts, count: texts.length)
        else
          element = find_element(selector)
          success_response(text: element.text)
        end
      rescue StandardError => e
        logger.error "Get text failed: #{e.message}"
        error_response("Failed to get text: #{e.message}")
      end
    end

    # Tool to get page HTML
    class GetHTMLTool < BaseTool
      def self.tool_name
        'get_html'
      end

      def self.description
        'Get HTML content of the page or a specific element'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            selector: {
              type: 'string',
              description: 'Optional: CSS selector to get HTML of specific element'
            }
          }
        }
      end

      def execute(params)
        ensure_browser_active
        selector = params['selector'] || params[:selector]

        if selector
          logger.info "Getting HTML of element: #{selector}"
          element = find_element(selector)
          html = element.property('outerHTML')
          success_response(html: html, selector: selector)
        else
          logger.info 'Getting page HTML'
          html = browser.body
          success_response(html: html, url: browser.url)
        end
      rescue StandardError => e
        logger.error "Get HTML failed: #{e.message}"
        error_response("Failed to get HTML: #{e.message}")
      end
    end

    # Tool to take screenshots
    class ScreenshotTool < BaseTool
      def self.tool_name
        'screenshot'
      end

      def self.description
        'Take a screenshot of the page or a specific element'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            selector: {
              type: 'string',
              description: 'Optional: CSS selector to screenshot specific element'
            },
            full_page: {
              type: 'boolean',
              description: 'Capture full scrollable page (default: false)',
              default: false
            },
            format: {
              type: 'string',
              enum: ['png', 'jpeg'],
              description: 'Image format (default: png)',
              default: 'png'
            }
          }
        }
      end

      def execute(params)
        ensure_browser_active
        selector = params['selector'] || params[:selector]
        full_page = params['full_page'] || params[:full_page] || false
        format = params['format'] || params[:format] || 'png'

        logger.info 'Taking screenshot'

        options = { format: format, full: full_page }
        screenshot_data = if selector
                            element = find_element(selector)
                            element.screenshot(**options)
                          else
                            browser.screenshot(**options)
                          end

        base64_data = Base64.strict_encode64(screenshot_data)

        success_response(
          screenshot: base64_data,
          format: format,
          encoding: 'base64'
        )
      rescue StandardError => e
        logger.error "Screenshot failed: #{e.message}"
        error_response("Failed to take screenshot: #{e.message}")
      end
    end

    # Tool to get page title
    class GetTitleTool < BaseTool
      def self.tool_name
        'get_title'
      end

      def self.description
        'Get the title of the current page'
      end

      def self.input_schema
        { type: 'object', properties: {} }
      end

      def execute(_params)
        ensure_browser_active
        logger.info 'Getting page title'

        success_response(
          title: browser.title,
          url: browser.url
        )
      rescue StandardError => e
        logger.error "Get title failed: #{e.message}"
        error_response("Failed to get title: #{e.message}")
      end
    end

    # Tool to get current URL
    class GetURLTool < BaseTool
      def self.tool_name
        'get_url'
      end

      def self.description
        'Get the current URL of the page'
      end

      def self.input_schema
        { type: 'object', properties: {} }
      end

      def execute(_params)
        ensure_browser_active
        logger.info 'Getting current URL'

        success_response(url: browser.url)
      rescue StandardError => e
        logger.error "Get URL failed: #{e.message}"
        error_response("Failed to get URL: #{e.message}")
      end
    end
  end
end
