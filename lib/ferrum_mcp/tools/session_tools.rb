# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Base class for session management tools
    class SessionTool
      attr_reader :session_manager, :logger

      def initialize(session_manager)
        @session_manager = session_manager
        @logger = session_manager.logger
      end

      def self.tool_name
        raise NotImplementedError, 'Subclasses must implement .tool_name'
      end

      def self.description
        raise NotImplementedError, 'Subclasses must implement .description'
      end

      def self.input_schema
        raise NotImplementedError, 'Subclasses must implement .input_schema'
      end

      protected

      def success_response(data = {})
        { success: true, data: data }
      end

      def error_response(message)
        { success: false, error: message }
      end
    end

    # Create a new browser session
    class CreateSessionTool < SessionTool
      def self.tool_name
        'create_session'
      end

      def self.description
        'Create a new browser session with custom options. Supports multiple browsers in parallel (Chrome, BotBrowser). Returns a session_id to use with other tools.'
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

    # List all active sessions
    class ListSessionsTool < SessionTool
      def self.tool_name
        'list_sessions'
      end

      def self.description
        'List all active browser sessions with their information (id, status, type, uptime, etc.)'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {}
        }
      end

      def execute(_params)
        sessions = session_manager.list_sessions
        success_response(
          count: sessions.size,
          sessions: sessions
        )
      rescue StandardError => e
        logger.error "Failed to list sessions: #{e.message}"
        error_response("Failed to list sessions: #{e.message}")
      end
    end

    # Close a specific session
    class CloseSessionTool < SessionTool
      def self.tool_name
        'close_session'
      end

      def self.description
        'Close a specific browser session by its ID. The browser will be stopped and the session will be removed.'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            session_id: {
              type: 'string',
              description: 'The ID of the session to close'
            }
          },
          required: ['session_id']
        }
      end

      def execute(params)
        session_id = params[:session_id] || params['session_id']

        return error_response('session_id is required') unless session_id

        success = session_manager.close_session(session_id)

        if success
          success_response(
            session_id: session_id,
            message: 'Session closed successfully'
          )
        else
          error_response("Session not found: #{session_id}")
        end
      rescue StandardError => e
        logger.error "Failed to close session: #{e.message}"
        error_response("Failed to close session: #{e.message}")
      end
    end

    # Get information about a specific session
    class GetSessionInfoTool < SessionTool
      def self.tool_name
        'get_session_info'
      end

      def self.description
        'Get detailed information about a specific browser session'
      end

      def self.input_schema
        {
          type: 'object',
          properties: {
            session_id: {
              type: 'string',
              description: 'The ID of the session (omit for default session)'
            }
          }
        }
      end

      def execute(params)
        session_id = params[:session_id] || params['session_id']
        session = session_manager.get_session(session_id)

        return error_response("Session not found: #{session_id}") unless session

        success_response(session.info)
      rescue StandardError => e
        logger.error "Failed to get session info: #{e.message}"
        error_response("Failed to get session info: #{e.message}")
      end
    end
  end
end
