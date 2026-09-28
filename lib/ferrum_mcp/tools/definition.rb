# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Class-level DSL shared by every tool.
    #
    #   class ClickTool < BaseTool
    #     tool_name 'click'
    #     description 'Click on an element'
    #     param :selector, type: :string, required: true, description: 'CSS selector'
    #     param :wait, type: :number, default: 5, description: 'Seconds to wait'
    #   end
    #
    # The JSON schema handed to MCP is generated from these declarations, the
    # session_id parameter is injected for tools that need a browser, and
    # incoming params are normalized (symbol keys, defaults applied) before
    # reaching #perform.
    module Definition
      SESSION_ID_SCHEMA = {
        type: 'string',
        description: 'Session ID to use for this operation (returned by create_session)'
      }.freeze

      TYPES = %i[string number integer boolean array object].freeze

      def tool_name(value = nil)
        return @tool_name = value.to_s if value

        @tool_name || raise(NotImplementedError, "#{name} must declare tool_name")
      end

      def description(value = nil)
        return @description = value if value

        @description || raise(NotImplementedError, "#{name} must declare description")
      end

      # Whether the tool operates on a browser session (session_id injected and
      # required). Session-management tools set this to false.
      def requires_session(value)
        @requires_session = value
      end

      def requires_session?
        return @requires_session unless @requires_session.nil?

        superclass.respond_to?(:requires_session?) ? superclass.requires_session? : true
      end

      # Declare an input parameter.
      # @param schema [Hash] extra JSON schema keywords (items, additionalProperties, ...)
      def param(name, type:, description:, required: false, default: nil, enum: nil, schema: {}) # rubocop:disable Metrics/ParameterLists
        raise ArgumentError, "Unknown param type #{type.inspect}" unless TYPES.include?(type.to_sym)

        param_definitions[name.to_sym] = {
          type: type.to_sym, description: description, required: required,
          default: default, enum: enum, schema: schema
        }
      end

      def param_definitions
        @param_definitions ||= {}
      end

      def input_schema
        properties = {}
        properties[:session_id] = SESSION_ID_SCHEMA if requires_session?
        param_definitions.each { |name, definition| properties[name] = json_schema_for(definition) }

        required = []
        required << 'session_id' if requires_session?
        required.concat(param_definitions.select { |_, d| d[:required] }.keys.map(&:to_s))

        schema = { type: 'object', properties: properties }
        schema[:required] = required.uniq unless required.empty?
        schema
      end

      # Symbol keys (recursively) and declared defaults applied.
      def normalize_params(raw_params)
        params = deep_symbolize(raw_params || {})
        param_definitions.each do |name, definition|
          params[name] = definition[:default] if params[name].nil? && !definition[:default].nil?
        end
        params
      end

      private

      def json_schema_for(definition)
        schema = { type: definition[:type].to_s, description: definition[:description] }
        schema[:default] = definition[:default] unless definition[:default].nil?
        schema[:enum] = definition[:enum] if definition[:enum]
        schema.merge(definition[:schema])
      end

      def deep_symbolize(value)
        case value
        when Hash then value.to_h { |k, v| [k.to_sym, deep_symbolize(v)] }
        when Array then value.map { |v| deep_symbolize(v) }
        else value
        end
      end
    end
  end
end
