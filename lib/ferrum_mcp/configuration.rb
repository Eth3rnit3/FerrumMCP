# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

module FerrumMCP
  # Configuration class for Ferrum MCP Server
  class Configuration
    attr_accessor :headless, :timeout, :server_host, :server_port, :log_level, :log_file, :transport,
                  :max_sessions, :rate_limit_enabled, :rate_limit_max_requests, :rate_limit_window,
                  :api_key_enabled, :api_keys, :trust_proxy,
                  :dns_rebinding_protection, :mcp_allowed_hosts, :mcp_allowed_origins
    attr_reader :browsers, :user_profiles, :bot_profiles, :url_policy, :upload_allowed_dirs

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
      @log_level = ENV.fetch('LOG_LEVEL', 'info').to_sym
      @log_file = ENV.fetch('LOG_FILE', nil)
      @transport = transport
      @max_sessions = ENV.fetch('MAX_CONCURRENT_SESSIONS', '10').to_i

      # Only honour X-Forwarded-For when the server sits behind a trusted proxy
      @trust_proxy = ENV.fetch('TRUST_PROXY', 'false') == 'true'

      # DNS rebinding protection of the MCP endpoint (HTTP transport): the
      # Host header must be loopback or listed in MCP_ALLOWED_HOSTS, and a
      # browser Origin must be same-origin or listed in MCP_ALLOWED_ORIGINS.
      @dns_rebinding_protection = ENV.fetch('DNS_REBINDING_PROTECTION', 'true') == 'true'
      @mcp_allowed_hosts = env_list('MCP_ALLOWED_HOSTS')
      @mcp_allowed_origins = env_list('MCP_ALLOWED_ORIGINS')

      # Optional navigation restrictions (ALLOWED_HOSTS / BLOCKED_HOSTS)
      @url_policy = UrlPolicy.from_env

      # Directories the upload_file tool may read from (UPLOAD_ALLOWED_DIRS)
      @upload_allowed_dirs = load_upload_allowed_dirs

      # Rate limiting configuration
      @rate_limit_enabled = ENV.fetch('RATE_LIMIT_ENABLED', 'true') == 'true'
      @rate_limit_max_requests = ENV.fetch('RATE_LIMIT_MAX_REQUESTS', '100').to_i
      @rate_limit_window = ENV.fetch('RATE_LIMIT_WINDOW', '60').to_i

      # API key authentication configuration
      @api_key_enabled = ENV.fetch('API_KEY_ENABLED', 'false') == 'true'
      @api_keys = load_api_keys

      load_browser_configurations
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
      @logger ||= create_logger
    end

    # Environment variable keys to skip when loading browsers
    RESERVED_BROWSER_ENV_KEYS = %w[BROWSER_PATH BROWSER_HEADLESS BROWSER_TIMEOUT].freeze

    # Check if API key authentication is properly configured
    def api_key_configured?
      api_key_enabled && api_keys.any?
    end

    private

    def load_browser_configurations
      @browsers = load_browsers
      @user_profiles = load_user_profiles
      @bot_profiles = load_bot_profiles
    end

    # Comma-separated environment variable as a list
    def env_list(name)
      ENV.fetch(name, '').split(',').map(&:strip).reject(&:empty?)
    end

    # Defaults to the current directory and the system temp dir
    def load_upload_allowed_dirs
      configured = env_list('UPLOAD_ALLOWED_DIRS')
      dirs = configured.empty? ? [Dir.pwd, Dir.tmpdir] : configured
      dirs.map { |d| File.expand_path(d) }
    end

    # Load API keys from environment variables
    # Supports single key (API_KEY) or multiple keys (API_KEYS=key1,key2,key3)
    def load_api_keys
      keys = []

      # Load single API key
      single_key = ENV.fetch('API_KEY', nil)
      keys << single_key if single_key && !single_key.empty?

      # Load multiple API keys (comma-separated)
      keys.concat(env_list('API_KEYS'))

      keys.uniq
    end

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

    # Logs never go to STDOUT: in stdio transport STDOUT carries the protocol.
    # LOG_FILE=<path> writes to that file, LOG_FILE=stderr writes to STDERR,
    # unset writes to ./logs/ferrum_mcp.log under the current directory (never
    # inside the installed gem), falling back to the system temp dir.
    def create_logger
      Logger.new(log_device, level: log_level)
    end

    def log_device
      target = log_file.to_s.strip
      return $stderr if target.casecmp('stderr').zero?
      return prepare_log_path(target) unless target.empty?

      prepare_log_path(File.join(Dir.pwd, 'logs', 'ferrum_mcp.log'))
    rescue SystemCallError
      File.join(Dir.tmpdir, 'ferrum_mcp.log')
    end

    def prepare_log_path(path)
      FileUtils.mkdir_p(File.dirname(path))
      path
    end
  end
end
