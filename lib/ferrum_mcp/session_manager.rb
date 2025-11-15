# frozen_string_literal: true

module FerrumMCP
  # Manages multiple browser sessions with thread-safety and automatic cleanup
  class SessionManager
    attr_reader :config, :logger

    # Default session timeout: 30 minutes
    DEFAULT_SESSION_TIMEOUT = 30 * 60
    # Default cleanup interval: 5 minutes
    DEFAULT_CLEANUP_INTERVAL = 5 * 60

    def initialize(config)
      @config = config
      @logger = config.logger
      @sessions = {}
      @mutex = Mutex.new
      @session_timeout = DEFAULT_SESSION_TIMEOUT
      @cleanup_thread = nil

      start_cleanup_thread
    end

    # Create a new session with custom options
    # @param options [Hash] Browser options for this session
    # @return [String] Session ID
    def create_session(options = {})
      @mutex.synchronize do
        session = Session.new(config: @config, options: options)
        @sessions[session.id] = session
        logger.info "Created session #{session.id} (#{session.browser_type})"
        session.id
      end
    end

    # Get a session by ID
    # @param session_id [String] Session ID (required)
    # @return [Session, nil]
    def get_session(session_id)
      raise ArgumentError, 'session_id is required' if session_id.nil? || session_id.empty?

      @mutex.synchronize do
        session = @sessions[session_id]
        unless session
          logger.warn "Session not found: #{session_id}"
          return nil
        end

        session
      end
    end

    # Close a specific session
    # @param session_id [String] Session ID
    # @return [Boolean] Success
    def close_session(session_id)
      @mutex.synchronize do
        session = @sessions[session_id]
        return false unless session

        logger.info "Closing session #{session_id}"
        session.stop
        @sessions.delete(session_id)

        true
      end
    end

    # List all active sessions
    # @return [Array<Hash>] Session information
    def list_sessions
      @mutex.synchronize do
        @sessions.values.map(&:info)
      end
    end

    # Get session count
    # @return [Integer]
    def session_count
      @mutex.synchronize { @sessions.size }
    end

    # Close all sessions
    def close_all_sessions
      @mutex.synchronize do
        logger.info "Closing all #{@sessions.size} sessions"
        @sessions.each_value(&:stop)
        @sessions.clear
      end
    end

    # Execute a block with a session (thread-safe)
    # @param session_id [String] Session ID (required)
    # @yield [BrowserManager] Browser manager for the session
    def with_session(session_id)
      raise ArgumentError, 'session_id is required' if session_id.nil? || session_id.empty?

      session = get_session(session_id)
      raise SessionError, "Session not found: #{session_id}" unless session

      # Start browser if not active
      session.start unless session.active?

      # Execute with thread-safe access
      session.with_browser { |browser_manager| yield browser_manager }
    end

    # Set session timeout (in seconds)
    # @param timeout [Integer] Timeout in seconds
    def session_timeout=(timeout)
      @mutex.synchronize do
        @session_timeout = timeout
        logger.info "Session timeout set to #{timeout} seconds"
      end
    end

    # Stop cleanup thread and close all sessions
    def shutdown
      logger.info 'Shutting down SessionManager'
      stop_cleanup_thread
      close_all_sessions
    end

    private

    # Start background thread for cleaning up idle sessions
    def start_cleanup_thread
      return if @cleanup_thread&.alive?

      @cleanup_thread = Thread.new do
        loop do
          sleep DEFAULT_CLEANUP_INTERVAL
          cleanup_idle_sessions
        rescue StandardError => e
          logger.error "Cleanup thread error: #{e.message}"
        end
      end

      @cleanup_thread.priority = -1 # Lower priority
      logger.debug 'Started session cleanup thread'
    end

    # Stop cleanup thread
    def stop_cleanup_thread
      return unless @cleanup_thread

      @cleanup_thread.kill
      @cleanup_thread.join(5) # Wait max 5 seconds
      @cleanup_thread = nil
      logger.debug 'Stopped session cleanup thread'
    end

    # Clean up idle sessions
    def cleanup_idle_sessions
      idle_sessions = []

      @mutex.synchronize do
        @sessions.each do |id, session|
          idle_sessions << id if session.idle?(@session_timeout)
        end
      end

      idle_sessions.each do |id|
        logger.info "Cleaning up idle session #{id}"
        close_session(id)
      end

      logger.debug "Cleaned up #{idle_sessions.size} idle sessions" if idle_sessions.any?
    end
  end

  # Custom error for session-related issues
  class SessionError < StandardError; end
end
