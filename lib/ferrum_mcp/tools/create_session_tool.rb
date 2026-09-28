# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Create a new browser session
    class CreateSessionTool < SessionTool
      tool_name 'create_session'
      description <<~DESC
        Create a new browser session with custom options.
        Supports multiple browsers in parallel (Chrome, BotBrowser).
        Returns a session_id to use with other tools.

        Note: When running in Docker (DOCKER=true), headless mode is mandatory.
        Attempting to create a non-headless session will result in an error.
      DESC

      param :browser_id, type: :string,
                         description: 'Optional: Browser ID to use (from ferrum://browsers resource)'
      param :user_profile_id, type: :string,
                              description: 'Optional: User profile ID to use (from ferrum://user-profiles resource)'
      param :bot_profile_id, type: :string,
                             description: 'Optional: BotBrowser profile ID to use (from ferrum://bot-profiles resource)'
      param :browser_path, type: :string,
                           description: 'Optional: Path to browser executable (legacy, prefer browser_id)'
      param :botbrowser_profile, type: :string,
                                 description: 'Optional: Path to BotBrowser profile (legacy, prefer bot_profile_id)'
      param :headless, type: :boolean,
                       description: 'Optional: Run browser in headless mode (default: BROWSER_HEADLESS). ' \
                                    'REQUIRED to be true when running in Docker.'
      param :timeout, type: :number, description: 'Optional: Browser timeout in seconds (default: 60)'
      param :browser_options, type: :object,
                              description: 'Optional: Additional Chrome command-line flags without the leading ' \
                                           'dashes (e.g. {"window-size": "1920,1080", "lang": "fr-FR"})',
                              schema: { additionalProperties: { type: 'string' } }
      param :metadata, type: :object,
                       description: 'Optional: Custom metadata for this session (e.g., {"user": "john"})',
                       schema: { additionalProperties: true }

      SESSION_OPTION_KEYS = %i[browser_id user_profile_id bot_profile_id browser_path botbrowser_profile
                               headless timeout browser_options metadata].freeze

      def perform(params)
        logger.info 'Creating new browser session'

        options = params.slice(*SESSION_OPTION_KEYS).compact
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
        return unless ENV['DOCKER'] == 'true'

        if options.key?(:headless) && options[:headless] == false
          raise 'Headless mode is required when running in Docker. ' \
                'Cannot create a non-headless session in a containerized environment.'
        end

        options[:headless] = true unless options.key?(:headless)
      end
    end
  end
end
