# frozen_string_literal: true

require 'etc'
require 'open3'

module FerrumMCP
  # Manages Ferrum browser lifecycle with BotBrowser integration
  class BrowserManager
    # Ferrum launches Chrome with ~35 test-harness flags (no extensions, no
    # background networking, hidden scrollbars, muted audio, ...). A stock
    # Chrome has none of them and reCAPTCHA trusts Ferrum's Chrome less (images
    # instead of a direct pass, same IP, no CDP attached). Only the defaults
    # needed to drive the browser, invisible to pages, are kept. Notably
    # dropped: disable-web-security, which turns site isolation off (Cloudflare
    # rejects CDP clicks into in-process frames), enable-automation, and
    # no-startup-window: Ferrum then creates its tab with Target.createTarget,
    # a tab reCAPTCHA distrusts; without it Ferrum drives Chrome's own tab.
    KEPT_FERRUM_DEFAULTS = %w[
      headless no-first-run keep-alive-for-test remote-allow-origins
      password-store use-mock-keychain
      disable-background-timer-throttling disable-backgrounding-occluded-windows disable-renderer-backgrounding
      disable-site-isolation-trials disable-blink-features
    ].freeze

    # Headless Chrome announces itself as "HeadlessChrome/x" (rejected outright
    # by Cloudflare) and reports an 800x600 screen smaller than its window.
    # Both are flags: flags also reach targets Ferrum never attaches to (the
    # out-of-process Turnstile iframe). But the --user-agent flag empties the
    # high-entropy client hints, which no stock Chrome does (brotector flags
    # it): the targets Ferrum attaches to also get a CDP override that restores
    # them (FerrumPatches::MaskedUserAgentTargets). Chrome fills in the brands
    # itself; the platform fields and full version are given.
    HEADLESS_SCREEN = '{1920x1080}'
    UA_PLATFORMS = {
      mac: 'Macintosh; Intel Mac OS X 10_15_7',
      windows: 'Windows NT 10.0; Win64; x64',
      linux: 'X11; Linux x86_64'
    }.freeze
    UA_METADATA_PLATFORMS = { mac: 'macOS', windows: 'Windows', linux: 'Linux' }.freeze

    # Full version of the Chrome binary ("154.0.8037.57"), nil when unknown
    def self.chrome_version(path)
      @chrome_versions ||= {}
      return @chrome_versions[path] if @chrome_versions.key?(path)

      binary = path || Ferrum::Browser::Options::Chrome.instance.detect_path
      output, = Open3.capture2(binary.to_s, '--version')
      @chrome_versions[path] = output[/\d+\.\d+\.\d+(\.\d+)?/]
    rescue StandardError
      @chrome_versions[path] = nil
    end

    # :mac, :windows or :linux. Not Ferrum::Utils::Platform.name, renamed to
    # platform_name in Ferrum 0.17.2 (Module#name answered in its place).
    def self.platform
      case RbConfig::CONFIG['host_os']
      when /darwin|mac os/ then :mac
      when /mswin|mingw|cygwin/ then :windows
      else :linux
      end
    end

    # OS version as Chrome reports it in the client hints ("major.minor.bugfix").
    # Windows reports an API contract version Ruby cannot read: left empty.
    def self.os_version
      raw = case platform
            when :mac then Open3.capture2('sw_vers', '-productVersion').first
            when :linux then Etc.uname[:release]
            end
      numbers = raw.to_s.scan(/\d+/).first(3)
      numbers.empty? ? '' : (numbers + %w[0 0]).first(3).join('.')
    rescue StandardError
      ''
    end

    # CPU architecture as Chrome reports it ("arm" or "x86"). The machine's,
    # not Ruby's: an x86 Ruby under Rosetta still runs the arm64 Chrome.
    def self.cpu_architecture
      arm = case platform
            when :mac then Open3.capture2('sysctl', '-n', 'hw.optional.arm64').first.strip == '1'
            when :linux then Etc.uname[:machine].match?(/arm|aarch64/)
            else RbConfig::CONFIG['host_cpu'].match?(/arm|aarch64/)
            end
      arm ? 'arm' : 'x86'
    rescue StandardError
      RbConfig::CONFIG['host_cpu'].match?(/arm|aarch64/) ? 'arm' : 'x86'
    end

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
      override = user_agent_override
      browser_options_hash[:user_agent_override] = override if override
      browser_options_hash[:mcp_logger] = logger # FerrumPatches warnings

      # Only set browser_path if explicitly configured
      browser_options_hash[:browser_path] = config.browser_path if config.browser_path

      FerrumPatches.apply!
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
      options = ferrum_default_options.merge(headless_disguise_options).merge(config.merged_browser_options)
      logger.info "Using BotBrowser profile: #{options['bot-profile']}" if options['bot-profile']
      logger.info "Using user profile: #{options['user-data-dir']}" if options['user-data-dir']
      options
    end

    # Ferrum's own defaults, trimmed (see Ferrum::Browser::Options::Chrome#merge_default)
    def ferrum_default_options
      defaults = Ferrum::Browser::Options::Chrome::DEFAULT_OPTIONS.slice(*KEPT_FERRUM_DEFAULTS)
      defaults = defaults.merge('no-default-browser-check' => nil)
      defaults = defaults.except('headless') unless config.headless
      defaults = defaults.merge('disable-gpu' => nil) if Ferrum::Utils::Platform.windows? # Chromium bug 737678
      defaults = defaults.merge('use-angle' => 'metal') if Ferrum::Utils::Platform.mac_arm?
      defaults
    end

    # BotBrowser profiles manage their own user agent and screen.
    def disguise_headless?
      config.headless && !config.using_botbrowser?
    end

    def headless_disguise_options
      return {} unless disguise_headless?

      options = { 'screen-info' => HEADLESS_SCREEN }
      options['user-agent'] = masked_user_agent if masked_user_agent
      options
    end

    # Emulation.setUserAgentOverride parameters, nil to leave Chrome's own.
    # A user agent chosen by the session wins.
    def user_agent_override
      return unless masked_user_agent && !config.merged_browser_options.key?('user-agent')

      platform = self.class.platform
      {
        userAgent: masked_user_agent,
        userAgentMetadata: {
          platform: UA_METADATA_PLATFORMS[platform], platformVersion: self.class.os_version,
          architecture: self.class.cpu_architecture,
          bitness: '64', model: '', mobile: false, wow64: false,
          fullVersion: self.class.chrome_version(config.browser_path)
        }
      }
    end

    # Chrome's user agent without "Headless", nil when the version is unknown
    def masked_user_agent
      return unless disguise_headless?

      version = self.class.chrome_version(config.browser_path)
      platform = UA_PLATFORMS[self.class.platform]
      return unless version && platform

      "Mozilla/5.0 (#{platform}) AppleWebKit/537.36 (KHTML, like Gecko) " \
        "Chrome/#{version.to_i}.0.0.0 Safari/537.36"
    end
  end
end
