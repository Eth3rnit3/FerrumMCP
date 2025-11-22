# frozen_string_literal: true

module FerrumMCP
  # Configuration class for Ferrum MCP Server
  class Configuration
    attr_accessor :headless, :timeout, :server_host, :server_port, :log_level, :transport, :max_sessions,
                  :rate_limit_enabled, :rate_limit_max_requests, :rate_limit_window
    attr_reader :browsers, :user_profiles, :bot_profiles

    # Browser configuration structure
    BrowserConfig = Struct.new(:id, :name, :path, :type, :description, keyword_init: true) do
      def to_h
        super.compact
      end
    end

    # User profile configuration structure
    UserProfileConfig = Struct.new(:id, :name, :path, :description, keyword_init: true) do
      def to_h
        super.compact
      end
    end

    # BotBrowser profile configuration structure
    BotProfileConfig = Struct.new(:id, :name, :path, :encrypted, :description, keyword_init: true) do
      def to_h
        super.compact
      end
    end

    def initialize(transport: 'http')
      # Server configuration
      @headless = ENV.fetch('BROWSER_HEADLESS', 'false') == 'true'
      @timeout = ENV.fetch('BROWSER_TIMEOUT', '60').to_i
      @server_host = ENV.fetch('MCP_SERVER_HOST', '0.0.0.0')
      @server_port = ENV.fetch('MCP_SERVER_PORT', '3000').to_i
      @log_level = ENV.fetch('LOG_LEVEL', 'debug').to_sym
      @transport = transport
      @max_sessions = ENV.fetch('MAX_CONCURRENT_SESSIONS', '10').to_i

      # Rate limiting configuration
      @rate_limit_enabled = ENV.fetch('RATE_LIMIT_ENABLED', 'true') == 'true'
      @rate_limit_max_requests = ENV.fetch('RATE_LIMIT_MAX_REQUESTS', '100').to_i
      @rate_limit_window = ENV.fetch('RATE_LIMIT_WINDOW', '60').to_i

      # Load multi-browser configurations
      @browsers = load_browsers
      @user_profiles = load_user_profiles
      @bot_profiles = load_bot_profiles
    end

    def valid?
      # Valid if at least one browser is configured
      browsers.any? && browsers.all? { |b| b.path.nil? || File.exist?(b.path) }
    end

    # Get default browser (first in list or system Chrome)
    def default_browser
      browsers.first
    end

    # Find browser by ID
    def find_browser(id)
      browsers.find { |b| b.id == id }
    end

    # Find user profile by ID
    def find_user_profile(id)
      user_profiles.find { |p| p.id == id }
    end

    # Find bot profile by ID
    def find_bot_profile(id)
      bot_profiles.find { |p| p.id == id }
    end

    # Check if any BotBrowser profile is configured
    def using_botbrowser?
      bot_profiles.any?
    end

    def logger
      @logger ||= create_multi_logger
    end

    # Environment variable keys to skip when loading browsers
    RESERVED_BROWSER_ENV_KEYS = %w[BROWSER_PATH BROWSER_HEADLESS BROWSER_TIMEOUT].freeze

    private

    # Load browser configurations from environment variables
    # Format: BROWSER_<ID>=type:path:name:description
    # Example: BROWSER_CHROME=chrome:/usr/bin/google-chrome:Google Chrome:Standard Chrome browser
    # Example: BROWSER_BOTBROWSER=botbrowser:/opt/botbrowser/chrome:BotBrowser:Anti-detection browser
    def load_browsers
      browsers = []
      browsers.concat(load_custom_browsers)
      browsers << load_legacy_browser if legacy_browser_configured?
      browsers << create_system_browser if browsers.empty?
      browsers
    end

    def load_custom_browsers
      ENV.each_with_object([]) do |(key, value), browsers|
        next unless key.start_with?('BROWSER_')
        next if RESERVED_BROWSER_ENV_KEYS.include?(key)

        browsers << parse_browser_config(key, value)
      end
    end

    def parse_browser_config(key, value)
      id = key.sub('BROWSER_', '').downcase
      type, path, name, description = value.split(':', 4)

      BrowserConfig.new(
        id: id,
        name: name || id.capitalize,
        path: path.empty? ? nil : path,
        type: type || 'chrome',
        description: description
      )
    end

    def legacy_browser_configured?
      ENV['BROWSER_PATH'] || ENV.fetch('BOTBROWSER_PATH', nil)
    end

    def load_legacy_browser
      legacy_path = ENV.fetch('BROWSER_PATH', nil) || ENV.fetch('BOTBROWSER_PATH', nil)
      legacy_type = ENV['BOTBROWSER_PATH'] ? 'botbrowser' : 'chrome'

      BrowserConfig.new(
        id: 'default',
        name: 'Default Browser',
        path: legacy_path,
        type: legacy_type,
        description: 'Legacy browser configuration'
      )
    end

    def create_system_browser
      BrowserConfig.new(
        id: 'system',
        name: 'System Chrome',
        path: nil,
        type: 'chrome',
        description: 'Auto-detected system Chrome/Chromium'
      )
    end

    # Load user profile configurations from environment variables
    # Format: USER_PROFILE_<ID>=path:name:description
    # Example: USER_PROFILE_DEV=/home/user/.chrome-dev:Development:Dev profile with extensions
    def load_user_profiles
      profiles = []

      ENV.each do |key, value|
        next unless key.start_with?('USER_PROFILE_')

        id = key.sub('USER_PROFILE_', '').downcase
        path, name, description = value.split(':', 3)

        next if path.nil? || path.empty?

        profiles << UserProfileConfig.new(
          id: id,
          name: name || id.capitalize,
          path: path,
          description: description
        )
      end

      profiles
    end

    # Load BotBrowser profile configurations from environment variables
    # Format: BOT_PROFILE_<ID>=path:name:description
    # Example: BOT_PROFILE_US=/profiles/us_chrome.enc:US Chrome:US-based Chrome profile
    def load_bot_profiles
      profiles = []

      ENV.each do |key, value|
        next unless key.start_with?('BOT_PROFILE_')

        id = key.sub('BOT_PROFILE_', '').downcase
        path, name, description = value.split(':', 3)

        next if path.nil? || path.empty?

        profiles << BotProfileConfig.new(
          id: id,
          name: name || id.capitalize,
          path: path,
          encrypted: path.end_with?('.enc'),
          description: description
        )
      end

      # Add legacy BOTBROWSER_PROFILE for backward compatibility
      if ENV['BOTBROWSER_PROFILE'] && !ENV['BOTBROWSER_PROFILE'].empty?
        legacy_path = ENV['BOTBROWSER_PROFILE']

        profiles << BotProfileConfig.new(
          id: 'default',
          name: 'Default BotBrowser Profile',
          path: legacy_path,
          encrypted: legacy_path.end_with?('.enc'),
          description: 'Legacy BotBrowser profile'
        )
      end

      profiles
    end

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
