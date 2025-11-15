# frozen_string_literal: true

module FerrumMCP
  module Tools
    class CreateSessionTool < SessionTool
      def self.tool_name
        'create_session'
      end

      def self.description
        <<~DESC
          Create a new browser session with custom options.
          Supports multiple browsers in parallel (Chrome, BotBrowser).
          Returns a session_id to use with other tools.
        DESC
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            browser_path: {
              type: 'string',
              description: 'Optional: Path to browser executable (Chrome/Chromium or BotBrowser)'
            },
            botbrowser_profile: {
              type: 'string',
              description: 'Optional: Path to BotBrowser profile for anti-detection mode'
            },
            headless: {
              type: 'boolean',
              description: 'Optional: Run browser in headless mode (default: false)'
            },
            timeout: {
              type: 'number',
              description: 'Optional: Browser timeout in seconds (default: 60)'
            },
            browser_options: {
              type: 'object',
              description: 'Optional: Additional browser command-line options (e.g., {"--window-size": "1920,1080"})',
              additionalProperties: { type: 'string' }
            },
            metadata: {
              type: 'object',
              description: 'Optional: Custom metadata for this session (e.g., {"user": "john", "project": "scraping"})',
              additionalProperties: true
            }
          }
        }
      end

      def execute(params)
        logger.info 'Creating new browser session'

        options = build_options(params)
        session_id = session_manager.create_session(options)

        success_response(
          session_id: session_id,
          message: 'Session created successfully',
          options: options.except(:metadata)
        )
      rescue StandardError => e
        logger.error "Failed to create session: #{e.message}"
        error_response("Failed to create session: #{e.message}")
      end

      private

      def build_options(params)
        options = {}
        if params[:browser_path] || params['browser_path']
          options[:browser_path] =
            params[:browser_path] || params['browser_path']
        end
        if params[:botbrowser_profile] || params['botbrowser_profile']
          options[:botbrowser_profile] =
            params[:botbrowser_profile] || params['botbrowser_profile']
        end
        if params.key?(:headless) || params.key?('headless')
          options[:headless] =
            params[:headless] || params['headless']
        end
        options[:timeout] = params[:timeout] || params['timeout'] if params[:timeout] || params['timeout']
        if params[:browser_options] || params['browser_options']
          options[:browser_options] =
            params[:browser_options] || params['browser_options']
        end
        options[:metadata] = params[:metadata] || params['metadata'] if params[:metadata] || params['metadata']
        options
      end
    end
  end
end
