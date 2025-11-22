# frozen_string_literal: true

# NOTE: ferrum_mcp is loaded in bin/ferrum-mcp before this file
require_relative '../transport/http_server'
require_relative '../transport/stdio_server'

module FerrumMCP
  module CLI
    # Handles server startup and lifecycle
    class ServerRunner
      attr_reader :config, :mcp_server, :transport_server

      def initialize(options = {})
        @options = options
        @config = Configuration.new(transport: options[:transport])
      end

      def validate!
        return if config.valid?

        puts 'ERROR: Invalid browser configuration'
        puts 'The specified BROWSER_PATH does not exist'
        puts ''
        puts 'Options:'
        puts '  1. Remove BROWSER_PATH to use system Chrome/Chromium'
        puts '  2. Set BROWSER_PATH to a valid browser executable'
        puts ''
        puts 'Example: export BROWSER_PATH=/path/to/chrome'
        exit 1
      end

      def start
        validate!
        setup_servers
        setup_signal_handlers
        log_startup_info
        run
      rescue StandardError => e
        config.logger.error "ERROR: #{e.message}"
        config.logger.error e.backtrace.join("\n")
        exit 1
      end

      private

      def setup_servers
        @mcp_server = Server.new(config)
        @transport_server = create_transport
      end

      def create_transport
        case @options[:transport]
        when 'stdio'
          Transport::StdioServer.new(mcp_server, config)
        when 'http'
          Transport::HTTPServer.new(mcp_server, config)
        else
          raise "Unknown transport: #{@options[:transport]}"
        end
      end

      def setup_signal_handlers
        trap('INT') { shutdown }
        trap('TERM') { shutdown }
      end

      def shutdown
        config.logger.info 'Shutting down...'
        transport_server.stop
        mcp_server.stop_browser
        exit 0
      end

      def log_startup_info
        logger = config.logger
        logger.info '=' * 60
        logger.info "Ferrum MCP Server v#{VERSION}"
        logger.info '=' * 60
        logger.info ''

        log_configuration
        log_transport_info

        logger.info ''
        logger.info '=' * 60
        logger.info 'Server starting...'
        logger.info '=' * 60
        logger.info ''
      end

      def log_configuration
        logger = config.logger
        logger.info 'Configuration:'

        log_browsers
        log_user_profiles
        log_bot_profiles
        log_browser_options
      end

      def log_browsers
        logger = config.logger
        logger.info "  Browsers (#{config.browsers.count}):"
        config.browsers.each do |browser|
          default_marker = browser == config.default_browser ? ' [default]' : ''
          browser_path = browser.path || 'auto-detect'
          logger.info "    - #{browser.id}: #{browser.name} (#{browser.type})#{default_marker}"
          logger.info "      Path: #{browser_path}"
        end
      end

      def log_user_profiles
        return unless config.user_profiles.any?

        logger = config.logger
        logger.info "  User Profiles (#{config.user_profiles.count}):"
        config.user_profiles.each do |profile|
          logger.info "    - #{profile.id}: #{profile.name}"
          logger.info "      Path: #{profile.path}"
        end
      end

      def log_bot_profiles
        logger = config.logger
        if config.bot_profiles.any?
          logger.info '  BotBrowser (anti-detection enabled) ✓'
          logger.info "  Bot Profiles (#{config.bot_profiles.count}):"
          config.bot_profiles.each do |profile|
            encrypted_marker = profile.encrypted ? ' [encrypted]' : ''
            logger.info "    - #{profile.id}: #{profile.name}#{encrypted_marker}"
            logger.info "      Path: #{profile.path}"
          end
        else
          logger.info '  BotBrowser: Not configured (consider using for better stealth)'
        end
      end

      def log_browser_options
        logger = config.logger
        logger.info "  Headless: #{config.headless}"
        logger.info "  Timeout: #{config.timeout}s"
        logger.info ''
      end

      def log_transport_info
        logger = config.logger
        logger.info 'Transport:'
        logger.info "  Protocol: #{@options[:transport].upcase}"

        if @options[:transport] == 'http'
          logger.info "  Host: #{config.server_host}"
          logger.info "  Port: #{config.server_port}"
          logger.info "  MCP Endpoint: http://#{config.server_host}:#{config.server_port}/mcp"
        else
          logger.info '  Mode: Standard input/output'
        end
      end

      def run
        transport_server.start
        # Keep main thread alive for HTTP (stdio blocks automatically)
        sleep if @options[:transport] == 'http'
      end
    end
  end
end
