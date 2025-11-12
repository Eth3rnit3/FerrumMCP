# frozen_string_literal: true

module FerrumMCP
  # Configuration class for Ferrum MCP Server
  class Configuration
    attr_accessor :browser_path, :botbrowser_profile, :headless, :timeout,
                  :server_host, :server_port, :log_level, :transport

    def initialize(transport: 'http')
      @browser_path = ENV.fetch('BROWSER_PATH', nil) || ENV.fetch('BOTBROWSER_PATH', nil)
      @botbrowser_profile = ENV.fetch('BOTBROWSER_PROFILE', nil)
      @headless = ENV.fetch('BROWSER_HEADLESS', 'false') == 'true'
      @timeout = ENV.fetch('BROWSER_TIMEOUT', '60').to_i
      @server_host = ENV.fetch('MCP_SERVER_HOST', '0.0.0.0')
      @server_port = ENV.fetch('MCP_SERVER_PORT', '3000').to_i
      @log_level = ENV.fetch('LOG_LEVEL', 'debug').to_sym
      @transport = transport
    end

    def valid?
      # Valid if browser_path is set and exists, OR if it's nil (will use system Chrome)
      browser_path.nil? || File.exist?(browser_path)
    end

    def using_botbrowser?
      !botbrowser_profile.nil? && !botbrowser_profile.empty?
    end

    def logger
      @logger ||= create_multi_logger
    end

    private

    def create_multi_logger
      # Create log directory relative to the project root
      # Use __FILE__ to get the gem's location, then go up to project root
      project_root = File.expand_path('../..', __dir__)
      log_dir = File.join(project_root, 'logs')
      FileUtils.mkdir_p(log_dir) unless File.directory?(log_dir)

      log_file = File.join(log_dir, 'ferrum_mcp.log')

      # Only write to file, no console output
      Logger.new(log_file, level: log_level)
    end
  end
end
