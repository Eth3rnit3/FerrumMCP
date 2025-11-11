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
      @log_level = ENV.fetch('LOG_LEVEL', 'info').to_sym
    end

    def valid?
      # Valid if browser_path is set and exists, OR if it's nil (will use system Chrome)
      browser_path.nil? || File.exist?(browser_path)
    end

    def using_botbrowser?
      !botbrowser_profile.nil? && !botbrowser_profile.empty?
    end

    def logger
      @logger ||= Logger.new($stdout, level: log_level)
    end
  end
end
