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
        if config.api_key_enabled && config.api_keys.empty?
          raise Error, 'API_KEY_ENABLED=true requires at least one key in API_KEY or API_KEYS'
        end

        @mcp_transport = MCP::Server::Transports::StreamableHTTPTransport.new(server.mcp_server, **transport_options)
        server.mcp_server.transport = @mcp_transport
      end

      # The SDK rejects a Host header that is neither loopback nor allow-listed
      # (DNS rebinding protection, MCP 2025-11-25). A server listening on a
      # public interface must name the hosts its clients use.
      def transport_options
        {
          dns_rebinding_protection: config.dns_rebinding_protection,
          allowed_hosts: config.mcp_allowed_hosts,
          allowed_origins: config.mcp_allowed_origins
        }
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
                window: config.rate_limit_window,
                trust_proxy: config.trust_proxy
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

          # MCP endpoint - use StreamableHTTPTransport. Authentication is
          # mounted here rather than globally with skip paths: Rack routes
          # "//mcp" to this endpoint too, and a "/" skip path matched it.
          map '/mcp' do
            if config.api_key_enabled
              use FerrumMCP::Transport::ApiKeyAuthenticator,
                  api_keys: config.api_keys,
                  logger: logger,
                  trust_proxy: config.trust_proxy
            end

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
        warn_about_host_validation
      end

      LOOPBACK_HOSTS = %w[127.0.0.1 ::1 localhost].freeze

      def warn_about_host_validation
        return unless config.dns_rebinding_protection
        return if LOOPBACK_HOSTS.include?(config.server_host) || config.mcp_allowed_hosts.any?

        logger.warn "Listening on #{config.server_host} but only loopback Host headers are accepted: " \
                    'clients reaching /mcp through another host name or IP get 403. ' \
                    'Set MCP_ALLOWED_HOSTS (e.g. "mcp.example.com,192.168.1.10") or DNS_REBINDING_PROTECTION=false ' \
                    'behind a proxy that validates Host itself.'
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
