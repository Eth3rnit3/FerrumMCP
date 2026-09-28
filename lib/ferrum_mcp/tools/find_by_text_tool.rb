# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Find elements by their text content
    class FindByTextTool < BaseTool
      tool_name 'find_by_text'
      description 'Find elements by their visible text content and return selectors to act on them'

      param :text, type: :string, required: true, description: 'Text to search for (exact match or contains)'
      param :tag, type: :string, default: '*',
                  description: 'HTML tag to search within (e.g. "button", "a"). "*" for any tag (default)'
      param :exact, type: :boolean, default: false,
                    description: 'Match the exact text (true) or a substring (false, default)'
      param :multiple, type: :boolean, default: false,
                       description: 'Return all matching elements (true) or just the first visible one (false)'

      def perform(params)
        ensure_browser_active
        text = params[:text].to_s
        tag = params[:tag].to_s.match?(/\A[\w*-]+\z/) ? params[:tag] : '*'
        logger.info "Finding elements with text: '#{text}' in <#{tag}> (exact: #{params[:exact]})"

        literal = xpath_literal(text)
        xpath = if params[:exact]
                  "//#{tag}[normalize-space(text())=#{literal}]"
                else
                  "//#{tag}[contains(normalize-space(.), #{literal})]"
                end

        elements = page.xpath(xpath)
        return error_response("No elements found with text: '#{text}'") if elements.empty?

        success_response(build_result(elements, xpath, params[:multiple]))
      rescue StandardError => e
        logger.error "Find by text failed: #{e.message}"
        error_response("Failed to find elements: #{e.message}")
      end

      private

      def build_result(elements, xpath, multiple)
        if multiple
          results = elements.map.with_index { |element, index| describe(element).merge(index: index) }
          { found: results.length, elements: results, xpath: xpath }
        else
          element = elements.find { |el| element_visible?(el) } || elements.first
          describe(element).merge(xpath: xpath, total_found: elements.length)
        end
      end

      def describe(element)
        {
          tag: element.tag_name,
          text: element.text.strip,
          visible: element_visible?(element),
          selector: generate_css_selector(element)
        }
      end

      def generate_css_selector(element)
        tag = element.tag_name
        id = element.property('id')
        classes = element.property('className')

        if id && !id.empty?
          "##{id}"
        elsif classes.is_a?(String) && !classes.strip.empty?
          "#{tag}.#{classes.split.join('.')}"
        else
          tag
        end
      rescue StandardError
        element.tag_name
      end
    end
  end
end
