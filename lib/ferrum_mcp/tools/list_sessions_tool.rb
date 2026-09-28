# frozen_string_literal: true

module FerrumMCP
  module Tools
    # List all active sessions
    class ListSessionsTool < SessionTool
      tool_name 'list_sessions'
      description 'List all active browser sessions with their information (id, status, type, uptime, etc.)'

      def perform(_params)
        sessions = session_manager.list_sessions
        success_response(count: sessions.size, sessions: sessions)
      rescue StandardError => e
        logger.error "Failed to list sessions: #{e.message}"
        error_response("Failed to list sessions: #{e.message}")
      end
    end
  end
end
