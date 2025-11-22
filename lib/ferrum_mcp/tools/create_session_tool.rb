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

          Note: When running in Docker (DOCKER=true), headless mode is mandatory.
          Attempting to create a non-headless session will result in an error.
        DESC
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            browser_id: {
              type: 'string',
              description: 'Optional: Browser ID to use (from ferrum://browsers resource)'
            },
            user_profile_id: {
              type: 'string',
              description: 'Optional: User profile ID to use (from ferrum://user-profiles resource)'
            },
            bot_profile_id: {
              type: 'string',
              description: 'Optional: BotBrowser profile ID to use (from ferrum://bot-profiles resource)'
            },
            browser_path: {
              type: 'string',
              description: 'Optional: Path to browser executable (legacy, prefer browser_id)'
            },
            botbrowser_profile: {
              type: 'string',
              description: 'Optional: Path to BotBrowser profile (legacy, prefer bot_profile_id)'
            },
            headless: {
              type: 'boolean',
              description: 'Optional: Run browser in headless mode (default: false). ' \
                           'REQUIRED to be true when running in Docker.'
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
        validate_docker_headless!(options)

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

      def validate_docker_headless!(options)
        # Check if running in Docker environment
        return unless ENV['DOCKER'] == 'true'

        # In Docker, headless mode is mandatory
        # Check if headless is explicitly set to false
        if options.key?(:headless) && options[:headless] == false
          raise 'Headless mode is required when running in Docker. ' \
                'Cannot create a non-headless session in a containerized environment.'
        end

        # Force headless to true in Docker if not explicitly set
        options[:headless] = true unless options.key?(:headless)
      end

      def build_options(params)
        options = {}

        # New resource-based parameters (preferred)
        if params[:browser_id] || params['browser_id']
          options[:browser_id] =
            params[:browser_id] || params['browser_id']
        end
        if params[:user_profile_id] || params['user_profile_id']
          options[:user_profile_id] =
            params[:user_profile_id] || params['user_profile_id']
        end
        if params[:bot_profile_id] || params['bot_profile_id']
          options[:bot_profile_id] =
            params[:bot_profile_id] || params['bot_profile_id']
        end

        # Legacy parameters (for backward compatibility)
        if params[:browser_path] || params['browser_path']
          options[:browser_path] =
            params[:browser_path] || params['browser_path']
        end
        if params[:botbrowser_profile] || params['botbrowser_profile']
          options[:botbrowser_profile] =
            params[:botbrowser_profile] || params['botbrowser_profile']
        end

        # Other options
        if params.key?(:headless) || params.key?('headless')
          # Use fetch to handle false values correctly
          options[:headless] = params.key?(:headless) ? params[:headless] : params['headless']
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
