# frozen_string_literal: true

module FerrumMCP
  # Manages Ferrum browser lifecycle with BotBrowser integration
  class BrowserManager
    attr_reader :browser, :config, :logger

    def initialize(config)
      @config = config
      @logger = config.logger
      @browser = nil
    end

    def start
      raise BrowserError, 'Browser path is invalid' unless config.valid?

      if config.using_botbrowser?
        logger.info 'Starting browser with BotBrowser (anti-detection mode)...'
      else
        logger.info 'Starting browser with standard Chrome/Chromium...'
      end

      browser_options_hash = {
        browser_options: computed_browser_options,
        headless: config.headless,
        timeout: config.timeout,
        process_timeout: ENV['CI'] ? 120 : config.timeout,
        pending_connection_errors: false
      }

      # Only set browser_path if explicitly configured
      browser_options_hash[:browser_path] = config.browser_path if config.browser_path

      @browser = Ferrum::Browser.new(**browser_options_hash)

      logger.info 'Browser started successfully'
      @browser
    rescue StandardError => e
      logger.error "Failed to start browser: #{e.message}"
      raise BrowserError, "Failed to start browser: #{e.message}"
    end

    def stop
      return unless @browser

      logger.info 'Stopping browser...'
      @browser.quit
      @browser = nil
      logger.info 'Browser stopped'
    rescue StandardError => e
      logger.error "Error stopping browser: #{e.message}"
    end

    def restart
      stop
      start
    end

    def active?
      !@browser.nil?
    end

    private

    # Compute browser options, merging defaults with session-specific options
    def computed_browser_options
      # Use merged options if config supports it (SessionConfiguration)
      if config.respond_to?(:merged_browser_options)
        options = config.merged_browser_options
      else
        options = browser_options
      end

      # Log BotBrowser profile usage
      if config.using_botbrowser? && config.botbrowser_profile && File.exist?(config.botbrowser_profile)
        logger.info "Using BotBrowser profile: #{config.botbrowser_profile}"
      end

      options
    end

    def browser_options
      options = {
        '--no-sandbox' => nil,
        '--disable-dev-shm-usage' => nil,
        '--disable-blink-features' => 'AutomationControlled',
        '--disable-gpu' => nil
      }

      # Additional options for CI environments
      options['--disable-setuid-sandbox'] = nil if ENV['CI']

      # Add BotBrowser profile if configured
      if config.using_botbrowser? && config.botbrowser_profile && File.exist?(config.botbrowser_profile)
        options['--bot-profile'] = config.botbrowser_profile
      end

      options
    end
  end
end
