# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Select option(s) in a <select>
    class SelectOptionTool < BaseTool
      tool_name 'select_option'
      description 'Select an option in a <select> element by value, label or index (values for multiple selects)'

      param :selector, type: :string, required: true, description: 'Selector of the <select> element'
      param :value, type: :string, description: 'Option value to select'
      param :label, type: :string, description: 'Option visible text to select'
      param :index, type: :integer, description: 'Zero-based option index to select'
      param :values, type: :array, description: 'Several option values (multiple selects)',
                     schema: { items: { type: 'string' } }

      def perform(params)
        ensure_browser_active
        selector = params[:selector]
        criteria = params.slice(:value, :label, :index, :values).compact
        raise ToolError, 'Provide one of value, label, index or values' if criteria.empty?

        logger.info "Selecting option in #{selector}: #{criteria.inspect}"
        element = find_element(selector)
        selected = page.evaluate(SELECT_SCRIPT, element, criteria.to_json)

        success_response(selector: selector,
                         selected: selected.map { |o| { value: o['value'], label: o['label'] } })
      rescue StandardError => e
        logger.error "Select option failed: #{e.message}"
        error_response("Failed to select option: #{e.message}")
      end

      SELECT_SCRIPT = <<~JS
        (function(select, json) {
          const criteria = JSON.parse(json);
          if (!select || select.tagName.toLowerCase() !== 'select') throw new Error('Element is not a <select>');
          const options = Array.from(select.options);
          const norm = (s) => (s || '').replace(/\\s+/g, ' ').trim();
          let wanted = [];
          if (criteria.values) wanted = options.filter(o => criteria.values.includes(o.value));
          else if (criteria.value != null) wanted = options.filter(o => o.value === criteria.value).slice(0, 1);
          else if (criteria.label != null) wanted = options.filter(o => norm(o.textContent) === norm(criteria.label)).slice(0, 1);
          else if (criteria.index != null) wanted = options[criteria.index] ? [options[criteria.index]] : [];
          if (wanted.length === 0) throw new Error('No option matches ' + json);
          if (!select.multiple) wanted = wanted.slice(0, 1);
          options.forEach(o => { o.selected = wanted.includes(o); });
          if (!select.multiple) select.value = wanted[0].value;
          select.dispatchEvent(new Event('input', { bubbles: true }));
          select.dispatchEvent(new Event('change', { bubbles: true }));
          return wanted.map(o => ({ value: o.value, label: norm(o.textContent) }));
        })(arguments[0], arguments[1])
      JS
    end
  end
end
