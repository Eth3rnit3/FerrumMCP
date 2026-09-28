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
      logger.info 'Browser stopped'
    rescue StandardError => e
      logger.error "Error stopping browser: #{e.message}"
    ensure
      @browser = nil
    end

    def restart
      stop
      start
    end

    def active?
      !@browser.nil?
    end

    # True when a browser is started and its Chrome process still exists.
    # Cheap (no CDP round-trip): a signal-0 check on the process id.
    def healthy?
      return false unless @browser

      pid = @browser.process&.pid
      return true unless pid

      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      logger.warn "Browser process #{pid} is gone"
      false
    rescue Errno::EPERM
      true
    end

    private

    # Browser flags come from the session configuration (defaults merged with
    # session-specific options, keys without leading dashes).
    def computed_browser_options
      options = config.merged_browser_options
      logger.info "Using BotBrowser profile: #{options['bot-profile']}" if options['bot-profile']
      logger.info "Using user profile: #{options['user-data-dir']}" if options['user-data-dir']
      options
    end
  end
end
