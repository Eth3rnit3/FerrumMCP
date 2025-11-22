# frozen_string_literal: true

require 'rack'
require 'json'

module FerrumMCP
  module Transport
    # HTTP Server with MCP StreamableHTTPTransport
    class HTTPServer
      attr_reader :server, :config, :logger, :mcp_transport

      def initialize(server, config)
        @server = server
        @config = config
        @logger = config.logger
        @mcp_transport = MCP::Server::Transports::StreamableHTTPTransport.new(server.mcp_server)
        server.mcp_server.transport = @mcp_transport
      end

      def app
        mcp_transport = @mcp_transport
        logger = @logger
        config = @config

        Rack::Builder.app do
          use Rack::CommonLogger, logger

          # Add rate limiting middleware if enabled
          if config.rate_limit_enabled
            use FerrumMCP::Transport::RateLimiter,
                max_requests: config.rate_limit_max_requests,
                window: config.rate_limit_window
          end

          # Health check endpoint
          map '/health' do
            run lambda { |_env|
              [200, { 'Content-Type' => 'application/json' }, [JSON.generate({ status: 'ok' })]]
            }
          end

          # Root endpoint
          map '/' do
            run lambda { |_env|
              body = {
                name: 'Ferrum MCP Server',
                version: FerrumMCP::VERSION,
                endpoints: {
                  mcp: '/mcp',
                  health: '/health'
                }
              }
              [200, { 'Content-Type' => 'application/json' }, [JSON.generate(body)]]
            }
          end

          # MCP endpoint - use StreamableHTTPTransport
          map '/mcp' do
            run lambda { |env|
              request = Rack::Request.new(env)
              mcp_transport.handle_request(request)
            }
          end
        end
      end

      def start
        require 'puma'

        logger.info "Starting HTTP server on #{config.server_host}:#{config.server_port}"

        @puma_server = Puma::Server.new(app)
        @puma_server.add_tcp_listener(config.server_host, config.server_port)

        @puma_thread = Thread.new do
          @puma_server.run.join
        end

        sleep 0.5

        logger.info 'HTTP server started'
        logger.info "MCP endpoint: http://#{config.server_host}:#{config.server_port}/mcp"
      end

      def stop
        logger.info 'Stopping HTTP server...'
        @puma_server&.stop(true)
        @puma_thread&.join
        logger.info 'HTTP server stopped'
      end
    end
  end
end
