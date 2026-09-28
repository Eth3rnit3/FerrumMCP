# frozen_string_literal: true

require 'json'

module FerrumMCP
  module Transport
    # STDIO Server with MCP StdioTransport
    #
    # The MCP transport owns the read loop: `open` blocks, reads one JSON-RPC
    # message per line from STDIN and writes responses to STDOUT until EOF.
    # Nothing else may write to STDOUT while the server runs, so logs go to a
    # file or STDERR (see LOG_FILE).
    class StdioServer
      attr_reader :server, :config, :logger, :mcp_transport

      def initialize(server, config)
        @server = server
        @config = config
        @logger = config.logger
        @mcp_transport = MCP::Server::Transports::StdioTransport.new(server.mcp_server)
        server.mcp_server.transport = @mcp_transport
      end

      def start
        logger.info 'Starting STDIO server (reading STDIN, writing STDOUT)'
        @mcp_transport.open
        logger.info 'STDIN closed, STDIO server finished'
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
