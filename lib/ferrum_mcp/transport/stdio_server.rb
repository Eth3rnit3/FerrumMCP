# frozen_string_literal: true

require 'json'

module FerrumMCP
  module Transport
    # STDIO Server with MCP StdioTransport
    class StdioServer
      attr_reader :server, :config, :logger, :mcp_transport

      def initialize(server, config)
        @server = server
        @config = config
        @logger = config.logger
        @mcp_transport = MCP::Server::Transports::StdioTransport.new(server.mcp_server)
        server.mcp_server.transport = @mcp_transport
      end

      def start # rubocop:disable Metrics/AbcSize
        logger.info 'Starting STDIO server'
        logger.info 'Reading from STDIN and writing to STDOUT'

        # Open the transport for stdio communication
        @mcp_transport.open

        # Read from stdin and process messages
        loop do
          line = $stdin.gets
          break if line.nil? # EOF

          begin
            request = JSON.parse(line.strip)
            response = @mcp_transport.handle_json_request(request)
            $stdout.puts(response.to_json)
            $stdout.flush
          rescue JSON::ParserError => e
            logger.error "Invalid JSON: #{e.message}"
            error_response = {
              jsonrpc: '2.0',
              error: { code: -32_700, message: 'Parse error' },
              id: nil
            }
            $stdout.puts(error_response.to_json)
            $stdout.flush
          rescue StandardError => e
            logger.error "Request error: #{e.message}"
            logger.error e.backtrace.join("\n")
          end
        end
      rescue StandardError => e
        logger.error "STDIO server error: #{e.message}"
        logger.error e.backtrace.join("\n")
        raise
      end

      def stop
        logger.info 'Stopping STDIO server...'
        @mcp_transport&.close
        logger.info 'STDIO server stopped'
      end
    end
  end
end
