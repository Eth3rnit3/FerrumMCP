# frozen_string_literal: true

module FerrumMCP
  # Configuration class for Ferrum MCP Server
  class Configuration
    attr_accessor :browser_path, :botbrowser_profile, :headless, :timeout,
                  :server_host, :server_port, :log_level

    def initialize
      @browser_path = ENV.fetch('BROWSER_PATH', nil) || ENV.fetch('BOTBROWSER_PATH', nil)
      @botbrowser_profile = ENV.fetch('BOTBROWSER_PROFILE', nil)
      @headless = ENV.fetch('BROWSER_HEADLESS', 'false') == 'true'
      @timeout = ENV.fetch('BROWSER_TIMEOUT', '60').to_i
      @server_host = ENV.fetch('MCP_SERVER_HOST', '0.0.0.0')
      @server_port = ENV.fetch('MCP_SERVER_PORT', '3000').to_i
      @log_level = ENV.fetch('LOG_LEVEL', 'debug').to_sym
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
      # Create log directory if it doesn't exist
      log_dir = File.join(Dir.pwd, 'logs')
      Dir.mkdir(log_dir) unless Dir.exist?(log_dir)

      log_file = File.join(log_dir, 'ferrum_mcp.log')

      # Create a logger that writes to both stdout and file
      stdout_logger = Logger.new($stdout, level: log_level)
      file_logger = Logger.new(log_file, level: log_level)

      # Create a custom logger that broadcasts to both
      multi_logger = Logger.new($stdout, level: log_level)
      multi_logger.define_singleton_method(:add) do |severity, message = nil, progname = nil, &block|
        stdout_logger.add(severity, message, progname, &block)
        file_logger.add(severity, message, progname, &block)
      end

      multi_logger
    end
  end
end
