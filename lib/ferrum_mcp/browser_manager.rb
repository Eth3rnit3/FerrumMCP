# frozen_string_literal: true

module FerrumMCP
  # Manages Ferrum browser lifecycle with BotBrowser integration
  class BrowserManager
    # Ferrum defaults that give automation away:
    # - disable-web-security switches site isolation off entirely, putting
    #   cross-origin frames (Cloudflare) in the page process, where input
    #   dispatched over CDP is rejected
    # - enable-automation shows the infobar and marks the browser as automated
    # Ferrum can only add flags, so its defaults are passed explicitly.
    DROPPED_FERRUM_DEFAULTS = %w[disable-web-security enable-automation].freeze

    attr_reader :browser, :config, :logger

    def initialize(config)
      @config = config
      @logger = config.logger
      @browser = nil
      @page = nil
    end

    # Current tab. Tools operate on this page so that tab switching works.
    def page
      raise BrowserError, 'Browser is not active' unless @browser

      @page = nil if @page && !page_open?(@page)
      @page ||= @browser.page
    end

    # All open tabs of the default browser context
    def pages
      raise BrowserError, 'Browser is not active' unless @browser

      @browser.pages
    end

    def select_page(page)
      @page = page
    end

    def create_page
      raise BrowserError, 'Browser is not active' unless @browser

      @browser.create_page
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
        pending_connection_errors: false,
        ignore_default_browser_options: true
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
      @page = nil
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

    def page_open?(page)
      @browser.pages.any? { |p| p.target_id == page.target_id }
    rescue StandardError
      false
    end

    # Browser flags come from the session configuration (defaults merged with
    # session-specific options, keys without leading dashes).
    def computed_browser_options
      options = ferrum_default_options.merge(config.merged_browser_options)
      logger.info "Using BotBrowser profile: #{options['bot-profile']}" if options['bot-profile']
      logger.info "Using user profile: #{options['user-data-dir']}" if options['user-data-dir']
      options
    end

    # What Ferrum would pass itself (see Ferrum::Browser::Options::Chrome#merge_default)
    def ferrum_default_options
      defaults = Ferrum::Browser::Options::Chrome::DEFAULT_OPTIONS.except(*DROPPED_FERRUM_DEFAULTS)
      defaults = defaults.except('headless', 'disable-gpu') unless config.headless
      defaults = defaults.merge('use-angle' => 'metal') if Ferrum::Utils::Platform.mac_arm?
      defaults
    end
  end
end
