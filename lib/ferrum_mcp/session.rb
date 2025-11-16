# frozen_string_literal: true

require 'securerandom'

module FerrumMCP
  # Represents a browser session with its own BrowserManager and configuration
  class Session
    attr_reader :id, :browser_manager, :config, :session_config, :created_at, :last_used_at, :metadata, :options

    def initialize(config:, options: {})
      @id = SecureRandom.uuid
      @config = config
      @options = normalize_options(options)
      @created_at = Time.now
      @last_used_at = Time.now
      @metadata = options[:metadata] || {}
      @mutex = Mutex.new
      @session_config, @browser_manager = create_browser_manager
    end

    # Execute a block with thread-safe access to the browser
    def with_browser
      @mutex.synchronize do
        @last_used_at = Time.now
        yield @browser_manager
      end
    end

    # Check if session is active (browser is running)
    def active?
      @browser_manager.active?
    end

    # Start the browser for this session
    def start
      @mutex.synchronize do
        @browser_manager.start unless @browser_manager.active?
        @last_used_at = Time.now
      end
    end

    # Stop the browser for this session
    def stop
      @mutex.synchronize do
        @browser_manager.stop if @browser_manager.active?
      end
    end

    # Check if session is idle (not used for a while)
    def idle?(timeout_seconds)
      Time.now - @last_used_at > timeout_seconds
    end

    # Get session information
    def info
      {
        id: @id,
        active: active?,
        created_at: @created_at.iso8601,
        last_used_at: @last_used_at.iso8601,
        idle_seconds: (Time.now - @last_used_at).to_i,
        metadata: @metadata,
        browser_type: browser_type,
        options: sanitized_options
      }
    end

    # Get browser type (public method for logging and info)
    def browser_type
      if @session_config.bot_profile
        "BotBrowser (#{@session_config.bot_profile.name})"
      elsif @session_config.browser
        # Check ID first (for system browser), then type
        if @session_config.browser.id == 'system'
          'System Chrome/Chromium'
        elsif @session_config.browser.type == 'botbrowser'
          "BotBrowser (#{@session_config.browser.name})"
        else
          @session_config.browser.name
        end
      else
        'System Chrome/Chromium'
      end
    end

    private

    def normalize_options(options)
      {
        browser_id: options[:browser_id] || options['browser_id'],
        browser_path: options[:browser_path] || options['browser_path'],
        user_profile_id: options[:user_profile_id] || options['user_profile_id'],
        bot_profile_id: options[:bot_profile_id] || options['bot_profile_id'],
        botbrowser_profile: options[:botbrowser_profile] || options['botbrowser_profile'],
        headless: options.fetch(:headless, options.fetch('headless', @config.headless)),
        timeout: options.fetch(:timeout, options.fetch('timeout', @config.timeout)),
        browser_options: options[:browser_options] || options['browser_options'] || {},
        metadata: options[:metadata] || options['metadata'] || {}
      }
    end

    def create_browser_manager
      # Create a custom configuration for this session
      session_config = SessionConfiguration.new(
        base_config: @config,
        overrides: @options
      )
      [session_config, BrowserManager.new(session_config)]
    end

    # Return sanitized options (without sensitive data)
    def sanitized_options
      @options.except(:metadata)
    end
  end

  # Session-specific configuration that overrides base configuration
  class SessionConfiguration
    attr_reader :browser, :user_profile, :bot_profile, :headless, :timeout,
                :server_host, :server_port, :log_level, :transport,
                :browser_options

    def initialize(base_config:, overrides:)
      @base_config = base_config
      @headless = overrides[:headless]
      @timeout = overrides[:timeout]
      @browser_options = overrides[:browser_options] || {}
      @server_host = base_config.server_host
      @server_port = base_config.server_port
      @log_level = base_config.log_level
      @transport = base_config.transport

      # Resolve browser configuration
      @browser = resolve_browser(overrides, base_config)
      @user_profile = resolve_user_profile(overrides, base_config)
      @bot_profile = resolve_bot_profile(overrides, base_config)
    end

    def valid?
      browser&.path.nil? || File.exist?(browser.path)
    end

    def using_botbrowser?
      browser&.type == 'botbrowser' || bot_profile&.path
    end

    # Legacy compatibility methods
    def browser_path
      browser&.path
    end

    def botbrowser_profile
      bot_profile&.path
    end

    def logger
      @base_config.logger
    end

    private

    def resolve_browser(overrides, base_config)
      # Priority: browser_id > browser_path (legacy) > default browser
      if overrides[:browser_id]
        base_config.find_browser(overrides[:browser_id])
      elsif overrides[:browser_path]
        # Legacy: create a temporary browser config
        Configuration::BrowserConfig.new(
          id: 'custom',
          name: 'Custom Browser',
          path: overrides[:browser_path],
          type: overrides[:botbrowser_profile] ? 'botbrowser' : 'chrome',
          description: 'Session-specific browser'
        )
      else
        base_config.default_browser
      end
    end

    def resolve_user_profile(overrides, base_config)
      # Priority: user_profile_id > nil
      return nil unless overrides[:user_profile_id]

      base_config.find_user_profile(overrides[:user_profile_id])
    end

    def resolve_bot_profile(overrides, base_config)
      # Priority: bot_profile_id > botbrowser_profile (legacy) > nil
      if overrides[:bot_profile_id]
        base_config.find_bot_profile(overrides[:bot_profile_id])
      elsif overrides[:botbrowser_profile]
        # Legacy: create a temporary bot profile config
        Configuration::BotProfileConfig.new(
          id: 'custom',
          name: 'Custom Profile',
          path: overrides[:botbrowser_profile],
          encrypted: overrides[:botbrowser_profile].end_with?('.enc'),
          description: 'Session-specific profile'
        )
      end
    end

    # Merge session-specific browser options with base options
    def merged_browser_options
      base_options = default_browser_options
      base_options.merge(@browser_options)
    end

    def default_browser_options
      options = {
        'no-sandbox' => nil,
        'disable-dev-shm-usage' => nil,
        'disable-blink-features' => 'AutomationControlled',
        'disable-gpu' => nil
      }

      options['disable-setuid-sandbox'] = nil if ENV['CI']

      # Add BotBrowser profile if configured
      if using_botbrowser? && botbrowser_profile && File.exist?(botbrowser_profile)
        options['bot-profile'] = botbrowser_profile
      end

      options
    end
  end
end
