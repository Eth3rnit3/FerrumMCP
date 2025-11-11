# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Tool to find elements by their text content
    class FindByTextTool < BaseTool
      def self.tool_name
        'find_by_text'
      end

      def self.description
        'Find elements by their text content using XPath'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            text: {
              type: 'string',
              description: 'Text to search for (exact match or contains)'
            },
            tag: {
              type: 'string',
              description: 'HTML tag to search within (e.g., "button", "a", "div"). Use "*" for any tag (default)',
              default: '*'
            },
            exact: {
              type: 'boolean',
              description: 'Whether to match exact text (true) or partial text (false, default)',
              default: false
            },
            multiple: {
              type: 'boolean',
              description: 'Return all matching elements (true) or just the first visible one (false, default)',
              default: false
            }
          },
          required: ['text']
        }
      end

      def execute(params)
        ensure_browser_active

        text = params['text'] || params[:text]
        tag = params['tag'] || params[:tag] || '*'
        exact = params['exact'] || params[:exact] || false
        multiple = params['multiple'] || params[:multiple] || false

        logger.info "Finding elements with text: '#{text}' in <#{tag}> tags (exact: #{exact}, multiple: #{multiple})"

        # Build XPath query
        xpath = if exact
                  "//#{tag}[normalize-space(text())='#{text}']"
                else
                  "//#{tag}[contains(normalize-space(.), '#{text}')]"
                end

        logger.debug "Using XPath: #{xpath}"

        elements = browser.xpath(xpath)
        return error_response("No elements found with text: '#{text}'") if elements.empty?

        if multiple
          # Find all matching elements

          results = elements.map.with_index do |element, index|
            {
              index: index,
              tag: element.tag_name,
              text: element.text.strip,
              visible: element_visible?(element),
              selector: generate_css_selector(element)
            }
          end

          success_response(
            found: results.length,
            elements: results,
            xpath: xpath
          )
        else
          # Find first visible element

          # Find first visible element
          visible_element = elements.find { |el| element_visible?(el) }
          element = visible_element || elements.first

          success_response(
            tag: element.tag_name,
            text: element.text.strip,
            visible: element_visible?(element),
            selector: generate_css_selector(element),
            xpath: xpath,
            total_found: elements.length
          )
        end
      rescue StandardError => e
        logger.error "Find by text failed: #{e.message}"
        error_response("Failed to find elements: #{e.message}")
      end

      private

      def element_visible?(element)
        rect = element.evaluate('el => el.getBoundingClientRect()')
        rect['width'].positive? && rect['height'].positive?
      rescue StandardError
        false
      end

      def generate_css_selector(element)
        # Try to generate a useful CSS selector
        tag = element.tag_name
        id = element.property('id')
        classes = element.property('className')

        if id && !id.empty?
          "##{id}"
        elsif classes && !classes.empty?
          class_list = classes.split.join('.')
          "#{tag}.#{class_list}"
        else
          tag
        end
      rescue StandardError
        element.tag_name
      end
    end
  end
end
