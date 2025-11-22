# frozen_string_literal: true

require_relative 'server_runner'
require_relative '../version'

module FerrumMCP
  module CLI
    # Handles CLI commands (help, version, start)
    class CommandHandler
      def self.handle(command, options)
        case command
        when 'start', nil
          start_server(options)
        when 'version', '-v', '--version'
          show_version
        when 'help', '-h', '--help'
          show_help
        else
          show_unknown_command(command)
        end
      end

      def self.start_server(options)
        # Load dependencies only when starting server
        require 'bundler/setup'
        require 'dotenv/load'

        # Set environment variables from options
        ENV['MCP_SERVER_HOST'] = options[:host]
        ENV['MCP_SERVER_PORT'] = options[:port].to_s
        ENV['LOG_LEVEL'] = options[:log_level]

        runner = ServerRunner.new(options)
        runner.start
      end

      def self.show_version
        puts "FerrumMCP #{VERSION}"
      end

      def self.show_help
        puts <<~HELP
          FerrumMCP - Browser Automation Server for Model Context Protocol

          USAGE:
              ferrum-mcp [COMMAND] [OPTIONS]

          COMMANDS:
              start       Start the FerrumMCP server (default)
              version     Show version information
              help        Show this help message

          OPTIONS:
              -t, --transport TYPE        Transport type: http or stdio (default: http)
              -H, --host HOST             Server host (default: 0.0.0.0)
              -p, --port PORT             Server port (default: 3000)
              -l, --log-level LEVEL       Log level: debug, info, warn, error (default: info)
              -h, --help                  Show this help message
              -v, --version               Show version

          EXAMPLES:
              # Start HTTP server on default port
              ferrum-mcp start

              # Start HTTP server on custom port
              ferrum-mcp start --port 8080

              # Start STDIO server (for Claude Desktop)
              ferrum-mcp start --transport stdio

              # Start with debug logging
              ferrum-mcp start --log-level debug

          ENVIRONMENT VARIABLES:
              MCP_SERVER_HOST             Server host (default: 0.0.0.0)
              MCP_SERVER_PORT             Server port (default: 3000)
              BROWSER_HEADLESS            Run browser in headless mode (default: true)
              BROWSER_TIMEOUT             Browser timeout in seconds (default: 60)
              LOG_LEVEL                   Log level (default: info)

              See .env.example for all configuration options.

          DOCUMENTATION:
              Getting Started: https://github.com/Eth3rnit3/FerrumMCP/blob/main/docs/GETTING_STARTED.md
              API Reference:   https://github.com/Eth3rnit3/FerrumMCP/blob/main/docs/API_REFERENCE.md
              Configuration:   https://github.com/Eth3rnit3/FerrumMCP/blob/main/docs/CONFIGURATION.md

          For more information, visit: https://github.com/Eth3rnit3/FerrumMCP
        HELP
      end

      def self.show_unknown_command(command)
        warn "Unknown command: #{command}"
        warn "Run 'ferrum-mcp help' for usage information"
        exit 1
      end
    end
  end
end
