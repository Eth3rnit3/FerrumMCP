# frozen_string_literal: true

module FerrumMCP
  module Tools
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
  end
end
