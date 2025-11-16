# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Multi-Browser and Multi-Profile Support' do
  describe 'Configuration' do
    context 'when no environment variables are set' do
      it 'creates a default system browser' do
        config = FerrumMCP::Configuration.new
        expect(config.browsers).not_to be_empty
        expect(config.browsers.first.id).to eq('system')
        expect(config.browsers.first.type).to eq('chrome')
        expect(config.browsers.first.path).to be_nil
      end

      it 'sets system browser as default' do
        config = FerrumMCP::Configuration.new
        expect(config.default_browser.id).to eq('system')
      end
    end

    context 'when custom browsers are configured' do
      before do
        ENV['BROWSER_CHROME'] = 'chrome:/usr/bin/google-chrome:Google Chrome:Standard browser'
        ENV['BROWSER_FIREFOX'] = 'firefox:/usr/bin/firefox:Firefox:Mozilla Firefox'
        ENV['BROWSER_BOTBROWSER'] = 'botbrowser:/opt/botbrowser/chrome:BotBrowser:Anti-detection'
      end

      it 'loads all configured browsers' do
        config = FerrumMCP::Configuration.new
        expect(config.browsers.count).to eq(3)

        browser_ids = config.browsers.map(&:id)
        expect(browser_ids).to include('chrome', 'firefox', 'botbrowser')
      end

      it 'parses browser configuration correctly' do
        config = FerrumMCP::Configuration.new
        chrome = config.find_browser('chrome')

        expect(chrome.id).to eq('chrome')
        expect(chrome.name).to eq('Google Chrome')
        expect(chrome.path).to eq('/usr/bin/google-chrome')
        expect(chrome.type).to eq('chrome')
        expect(chrome.description).to eq('Standard browser')
      end

      it 'sets first browser as default' do
        config = FerrumMCP::Configuration.new
        expect(config.default_browser.id).to eq('chrome')
      end

      it 'handles empty path in configuration' do
        ENV['BROWSER_SYSTEM'] = 'chrome::System Chrome:Use system Chrome'
        config = FerrumMCP::Configuration.new

        system_browser = config.find_browser('system')
        expect(system_browser.path).to be_nil
      end
    end

    context 'when user profiles are configured' do
      before do
        ENV['USER_PROFILE_DEV'] = '/home/user/.chrome-dev:Development:Dev profile'
        ENV['USER_PROFILE_PROD'] = '/home/user/.chrome-prod:Production:Prod profile'
      end

      it 'loads all user profiles' do
        config = FerrumMCP::Configuration.new
        expect(config.user_profiles.count).to eq(2)

        profile_ids = config.user_profiles.map(&:id)
        expect(profile_ids).to include('dev', 'prod')
      end

      it 'parses user profile configuration correctly' do
        config = FerrumMCP::Configuration.new
        dev_profile = config.find_user_profile('dev')

        expect(dev_profile.id).to eq('dev')
        expect(dev_profile.name).to eq('Development')
        expect(dev_profile.path).to eq('/home/user/.chrome-dev')
        expect(dev_profile.description).to eq('Dev profile')
      end
    end

    context 'when BotBrowser profiles are configured' do
      before do
        ENV['BOT_PROFILE_US'] = '/profiles/us.enc:US Chrome:US fingerprint'
        ENV['BOT_PROFILE_EU'] = '/profiles/eu.enc:EU Firefox:EU fingerprint'
        ENV['BOT_PROFILE_MOBILE'] = '/profiles/mobile.json:Mobile:Mobile fingerprint'
      end

      it 'loads all bot profiles' do
        config = FerrumMCP::Configuration.new
        expect(config.bot_profiles.count).to eq(3)

        profile_ids = config.bot_profiles.map(&:id)
        expect(profile_ids).to include('us', 'eu', 'mobile')
      end

      it 'detects encrypted profiles correctly' do
        config = FerrumMCP::Configuration.new

        us_profile = config.find_bot_profile('us')
        mobile_profile = config.find_bot_profile('mobile')

        expect(us_profile.encrypted).to be true
        expect(mobile_profile.encrypted).to be false
      end

      it 'parses bot profile configuration correctly' do
        config = FerrumMCP::Configuration.new
        us_profile = config.find_bot_profile('us')

        expect(us_profile.id).to eq('us')
        expect(us_profile.name).to eq('US Chrome')
        expect(us_profile.path).to eq('/profiles/us.enc')
        expect(us_profile.description).to eq('US fingerprint')
      end

      it 'indicates botbrowser usage when profiles exist' do
        config = FerrumMCP::Configuration.new
        expect(config.using_botbrowser?).to be true
      end
    end

    context 'with legacy environment variables' do
      before do
        ENV['BROWSER_PATH'] = '/custom/chrome'
      end

      it 'creates default browser from legacy BROWSER_PATH' do
        config = FerrumMCP::Configuration.new

        default_browser = config.find_browser('default')
        expect(default_browser).not_to be_nil
        expect(default_browser.path).to eq('/custom/chrome')
        expect(default_browser.type).to eq('chrome')
      end
    end

    context 'with legacy BotBrowser variables' do
      before do
        ENV['BOTBROWSER_PATH'] = '/custom/botbrowser'
        ENV['BOTBROWSER_PROFILE'] = '/custom/profile.enc'
      end

      it 'creates default browser from legacy BOTBROWSER_PATH' do
        config = FerrumMCP::Configuration.new

        default_browser = config.find_browser('default')
        expect(default_browser).not_to be_nil
        expect(default_browser.path).to eq('/custom/botbrowser')
        expect(default_browser.type).to eq('botbrowser')
      end

      it 'creates default bot profile from legacy BOTBROWSER_PROFILE' do
        config = FerrumMCP::Configuration.new

        default_profile = config.find_bot_profile('default')
        expect(default_profile).not_to be_nil
        expect(default_profile.path).to eq('/custom/profile.enc')
        expect(default_profile.encrypted).to be true
      end
    end

    context 'with mixed legacy and new configurations' do
      before do
        ENV['BROWSER_PATH'] = '/custom/chrome'
        ENV['BROWSER_FIREFOX'] = 'firefox:/usr/bin/firefox:Firefox:Mozilla'
      end

      it 'loads both legacy and new browsers' do
        config = FerrumMCP::Configuration.new

        expect(config.browsers.count).to eq(2)
        expect(config.find_browser('default')).not_to be_nil
        expect(config.find_browser('firefox')).not_to be_nil
      end

      it 'sets first configured browser as default when legacy exists' do
        config = FerrumMCP::Configuration.new
        # Firefox is loaded first from ENV.each, then legacy
        expect(config.default_browser.id).to eq('firefox')
      end
    end

    context 'when browsers configuration has missing values' do
      before do
        ENV['BROWSER_INCOMPLETE'] = 'chrome:/usr/bin/chrome'
      end

      it 'uses ID as default name when name is missing' do
        config = FerrumMCP::Configuration.new
        browser = config.find_browser('incomplete')

        expect(browser.name).to eq('Incomplete')
      end

      it 'stores empty string for type when type field is empty' do
        ENV['BROWSER_NO_TYPE'] = ':/usr/bin/browser:Browser:Description'

        config = FerrumMCP::Configuration.new
        browser = config.find_browser('no_type')

        # Empty string in config results in empty type, not 'chrome'
        expect(browser.type).to eq('')
      end

      it 'handles empty paths (skips them)' do
        ENV['USER_PROFILE_EMPTY'] = ':Name:Description'

        config = FerrumMCP::Configuration.new
        profile = config.find_user_profile('empty')

        # Should be nil because path is empty
        expect(profile).to be_nil
      end

      it 'handles empty bot profile paths (skips them)' do
        ENV['BOT_PROFILE_EMPTY'] = ':Name:Description'

        config = FerrumMCP::Configuration.new
        profile = config.find_bot_profile('empty')

        # Should be nil because path is empty
        expect(profile).to be_nil
      end

      it 'handles legacy BOTBROWSER_PROFILE when empty' do
        ENV['BOTBROWSER_PROFILE'] = ''

        config = FerrumMCP::Configuration.new
        # Should not create a bot profile for empty string
        expect(config.bot_profiles).to be_empty
      end
    end

    context 'when user profile has missing description' do
      before do
        ENV['USER_PROFILE_SIMPLE'] = '/path/to/profile:Simple'
      end

      it 'handles missing description gracefully' do
        config = FerrumMCP::Configuration.new
        profile = config.find_user_profile('simple')

        expect(profile.description).to be_nil
      end
    end

    context 'when bot profile has missing description' do
      before do
        ENV['BOT_PROFILE_SIMPLE'] = '/path/to/profile.enc:Simple'
      end

      it 'handles missing description gracefully' do
        config = FerrumMCP::Configuration.new
        profile = config.find_bot_profile('simple')

        expect(profile.description).to be_nil
      end
    end

    describe 'find methods' do
      before do
        ENV['BROWSER_CHROME'] = 'chrome:/usr/bin/chrome:Chrome:Standard'
        ENV['USER_PROFILE_DEV'] = '/home/.chrome-dev:Dev:Dev'
        ENV['BOT_PROFILE_US'] = '/profiles/us.enc:US:US'
      end

      it 'finds browser by id' do
        config = FerrumMCP::Configuration.new
        browser = config.find_browser('chrome')
        expect(browser).not_to be_nil
        expect(browser.id).to eq('chrome')
      end

      it 'returns nil for non-existent browser' do
        config = FerrumMCP::Configuration.new
        browser = config.find_browser('nonexistent')
        expect(browser).to be_nil
      end

      it 'finds user profile by id' do
        config = FerrumMCP::Configuration.new
        profile = config.find_user_profile('dev')
        expect(profile).not_to be_nil
        expect(profile.id).to eq('dev')
      end

      it 'returns nil for non-existent user profile' do
        config = FerrumMCP::Configuration.new
        profile = config.find_user_profile('nonexistent')
        expect(profile).to be_nil
      end

      it 'finds bot profile by id' do
        config = FerrumMCP::Configuration.new
        profile = config.find_bot_profile('us')
        expect(profile).not_to be_nil
        expect(profile.id).to eq('us')
      end

      it 'returns nil for non-existent bot profile' do
        config = FerrumMCP::Configuration.new
        profile = config.find_bot_profile('nonexistent')
        expect(profile).to be_nil
      end
    end

    describe 'default_browser' do
      it 'returns first browser as default' do
        ENV['BROWSER_CHROME'] = 'chrome:/usr/bin/chrome:Chrome:Standard'
        ENV['BROWSER_FIREFOX'] = 'firefox:/usr/bin/firefox:Firefox:Mozilla'

        config = FerrumMCP::Configuration.new
        expect(config.default_browser.id).to eq('chrome')
      end

      it 'returns system browser when no custom browsers' do
        config = FerrumMCP::Configuration.new
        expect(config.default_browser.id).to eq('system')
      end
    end

    describe 'using_botbrowser?' do
      it 'returns true when bot profiles exist' do
        ENV['BOT_PROFILE_US'] = '/profiles/us.enc:US:US'
        config = FerrumMCP::Configuration.new
        expect(config.using_botbrowser?).to be true
      end

      it 'returns false when no bot profiles' do
        config = FerrumMCP::Configuration.new
        expect(config.using_botbrowser?).to be false
      end
    end
  end

  describe 'SessionConfiguration' do
    let(:base_config) { FerrumMCP::Configuration.new }

    before do
      ENV['BROWSER_CHROME'] = 'chrome:/usr/bin/google-chrome:Google Chrome:Standard'
      ENV['BROWSER_BOTBROWSER'] = 'botbrowser:/opt/botbrowser:BotBrowser:Anti-detection'
      ENV['BOT_PROFILE_US'] = '/profiles/us.enc:US Chrome:US fingerprint'
      ENV['USER_PROFILE_DEV'] = '/home/user/.chrome-dev:Dev:Dev profile'
    end

    context 'when using browser_id' do
      it 'resolves browser by ID' do
        session_config = FerrumMCP::Session.new(
          config: base_config,
          options: { browser_id: 'chrome' }
        ).session_config

        expect(session_config.browser.id).to eq('chrome')
        expect(session_config.browser.name).to eq('Google Chrome')
      end

      it 'returns nil for non-existent browser ID' do
        session_config = FerrumMCP::Session.new(
          config: base_config,
          options: { browser_id: 'nonexistent' }
        ).session_config

        expect(session_config.browser).to be_nil
      end
    end

    context 'when using user_profile_id' do
      it 'resolves user profile by ID' do
        session_config = FerrumMCP::Session.new(
          config: base_config,
          options: { user_profile_id: 'dev' }
        ).session_config

        expect(session_config.user_profile.id).to eq('dev')
        expect(session_config.user_profile.name).to eq('Dev')
      end

      it 'returns nil when no user profile specified' do
        session_config = FerrumMCP::Session.new(
          config: base_config,
          options: {}
        ).session_config

        expect(session_config.user_profile).to be_nil
      end
    end

    context 'when using bot_profile_id' do
      it 'resolves bot profile by ID' do
        session_config = FerrumMCP::Session.new(
          config: base_config,
          options: { bot_profile_id: 'us' }
        ).session_config

        expect(session_config.bot_profile.id).to eq('us')
        expect(session_config.bot_profile.name).to eq('US Chrome')
      end

      it 'returns nil when no bot profile specified' do
        session_config = FerrumMCP::Session.new(
          config: base_config,
          options: {}
        ).session_config

        expect(session_config.bot_profile).to be_nil
      end
    end

    context 'with legacy browser_path' do
      it 'creates custom browser config from path' do
        session_config = FerrumMCP::Session.new(
          config: base_config,
          options: { browser_path: '/custom/browser' }
        ).session_config

        expect(session_config.browser.id).to eq('custom')
        expect(session_config.browser.path).to eq('/custom/browser')
        expect(session_config.browser.type).to eq('chrome')
      end
    end

    context 'with legacy botbrowser_profile' do
      it 'creates custom bot profile from path' do
        session_config = FerrumMCP::Session.new(
          config: base_config,
          options: { botbrowser_profile: '/custom/profile.enc' }
        ).session_config

        expect(session_config.bot_profile.id).to eq('custom')
        expect(session_config.bot_profile.path).to eq('/custom/profile.enc')
        expect(session_config.bot_profile.encrypted).to be true
      end

      it 'marks browser as botbrowser when profile is provided' do
        session_config = FerrumMCP::Session.new(
          config: base_config,
          options: {
            browser_path: '/custom/browser',
            botbrowser_profile: '/custom/profile.enc'
          }
        ).session_config

        expect(session_config.browser.type).to eq('botbrowser')
      end
    end

    context 'when using default behavior' do
      it 'uses default browser when no options provided' do
        session_config = FerrumMCP::Session.new(
          config: base_config,
          options: {}
        ).session_config

        expect(session_config.browser.id).to eq('chrome')
      end

      it 'provides legacy compatibility methods' do
        session_config = FerrumMCP::Session.new(
          config: base_config,
          options: { browser_id: 'chrome' }
        ).session_config

        expect(session_config.browser_path).to eq('/usr/bin/google-chrome')
        expect(session_config.botbrowser_profile).to be_nil
      end

      it 'returns nil for browser_path when browser has no path' do
        ENV['BROWSER_SYSTEM'] = 'chrome::System:System browser'
        session_config = FerrumMCP::Session.new(
          config: base_config,
          options: { browser_id: 'system' }
        ).session_config

        expect(session_config.browser_path).to be_nil
      end

      it 'detects botbrowser usage from browser type' do
        session_config = FerrumMCP::Session.new(
          config: base_config,
          options: { browser_id: 'botbrowser' }
        ).session_config

        expect(session_config.using_botbrowser?).to be true
      end

      it 'detects botbrowser usage from bot profile' do
        session_config = FerrumMCP::Session.new(
          config: base_config,
          options: { bot_profile_id: 'us' }
        ).session_config

        expect(session_config.using_botbrowser?).to be true
      end

      it 'returns false for using_botbrowser when neither type nor profile' do
        session_config = FerrumMCP::Session.new(
          config: base_config,
          options: { browser_id: 'chrome' }
        ).session_config

        expect(session_config.using_botbrowser?).to be false
      end

      it 'checks validity when browser has no path (uses nil for system browser)' do
        ENV['BROWSER_SYSTEM'] = 'chrome::System:System browser'
        system_config = FerrumMCP::Configuration.new
        session_config = FerrumMCP::Session.new(
          config: system_config,
          options: { browser_id: 'system' }
        ).session_config
        # Browser with nil path should be valid
        expect(session_config.valid?).to be true
      end

      it 'checks validity when browser has non-existent path' do
        session_config = FerrumMCP::Session.new(
          config: base_config,
          options: { browser_id: 'chrome' }
        ).session_config
        # Non-existent path (/usr/bin/google-chrome on macOS) should be invalid
        expect(session_config.valid?).to be false
      end
    end

    context 'when resolving with string keys' do
      it 'resolves browser_id from string key' do
        session_config = FerrumMCP::Session.new(
          config: base_config,
          options: { 'browser_id' => 'chrome' }
        ).session_config

        expect(session_config.browser.id).to eq('chrome')
      end

      it 'resolves bot_profile_id from string key' do
        session_config = FerrumMCP::Session.new(
          config: base_config,
          options: { 'bot_profile_id' => 'us' }
        ).session_config

        expect(session_config.bot_profile.id).to eq('us')
      end
    end
  end

  describe 'Session browser_type' do
    let(:base_config) { FerrumMCP::Configuration.new }

    before do
      ENV['BROWSER_CHROME'] = 'chrome:/usr/bin/chrome:Chrome:Standard'
      ENV['BROWSER_BOTBROWSER'] = 'botbrowser:/opt/botbrowser:BotBrowser:Anti-detection'
      ENV['BOT_PROFILE_US'] = '/profiles/us.enc:US Chrome:US fingerprint'
    end

    it 'returns system browser type for default session' do
      session = FerrumMCP::Session.new(config: base_config, options: {})
      expect(session.browser_type).to eq('Chrome')
    end

    it 'returns system Chrome when browser is nil' do
      # Create session with non-existent browser to get nil
      session = FerrumMCP::Session.new(
        config: base_config,
        options: { browser_id: 'nonexistent' }
      )
      expect(session.browser_type).to eq('System Chrome/Chromium')
    end

    it 'returns browser name for named browser' do
      session = FerrumMCP::Session.new(
        config: base_config,
        options: { browser_id: 'chrome' }
      )
      expect(session.browser_type).to eq('Chrome')
    end

    it 'returns BotBrowser with browser name for botbrowser type' do
      session = FerrumMCP::Session.new(
        config: base_config,
        options: { browser_id: 'botbrowser' }
      )
      expect(session.browser_type).to eq('BotBrowser (BotBrowser)')
    end

    it 'returns BotBrowser with profile name when bot profile is used' do
      session = FerrumMCP::Session.new(
        config: base_config,
        options: { bot_profile_id: 'us' }
      )
      expect(session.browser_type).to eq('BotBrowser (US Chrome)')
    end

    it 'returns Custom Browser for legacy browser_path' do
      session = FerrumMCP::Session.new(
        config: base_config,
        options: { browser_path: '/custom/chrome' }
      )
      expect(session.browser_type).to eq('Custom Browser')
    end

    it 'prioritizes bot profile over browser type' do
      session = FerrumMCP::Session.new(
        config: base_config,
        options: {
          browser_id: 'botbrowser',
          bot_profile_id: 'us'
        }
      )
      expect(session.browser_type).to eq('BotBrowser (US Chrome)')
    end
  end

  describe 'ResourceManager' do
    let(:config) { FerrumMCP::Configuration.new }
    let(:resource_manager) { FerrumMCP::ResourceManager.new(config) }

    before do
      ENV['BROWSER_CHROME'] = 'chrome:/usr/bin/chrome:Chrome:Standard'
      ENV['BROWSER_BOTBROWSER'] = 'botbrowser:/opt/botbrowser:BotBrowser:Anti-detection'
      ENV['USER_PROFILE_DEV'] = '/home/user/.chrome-dev:Dev:Dev profile'
      ENV['BOT_PROFILE_US'] = '/profiles/us.enc:US:US fingerprint'
    end

    describe 'browsers resource' do
      it 'includes all configured browsers' do
        result = resource_manager.read_resource('ferrum://browsers')
        data = JSON.parse(result[:text])

        expect(data['browsers'].count).to eq(2)
        expect(data['total']).to eq(2)
        expect(data['default']).to eq('chrome')
      end

      it 'includes individual browser resources' do
        resources = resource_manager.resources
        browser_resources = resources.select { |r| r.uri.start_with?('ferrum://browsers/') }

        expect(browser_resources.count).to eq(2)
        expect(browser_resources.map(&:uri)).to include(
          'ferrum://browsers/chrome',
          'ferrum://browsers/botbrowser'
        )
      end

      it 'provides detailed browser information' do
        result = resource_manager.read_resource('ferrum://browsers/chrome')
        data = JSON.parse(result[:text])

        aggregate_failures do
          expect(data['id']).to eq('chrome')
          expect(data['name']).to eq('Chrome')
          expect(data['type']).to eq('chrome')
          expect(data['path']).to eq('/usr/bin/chrome')
          expect(data['is_default']).to be true
          expect(data).to have_key('usage')
          expect(data['usage']['example']).to include("browser_id: 'chrome'")
        end
      end
    end

    describe 'user profiles resource' do
      it 'lists all user profiles' do
        result = resource_manager.read_resource('ferrum://user-profiles')
        data = JSON.parse(result[:text])

        expect(data['profiles'].count).to eq(1)
        expect(data['total']).to eq(1)
      end

      it 'provides detailed user profile information' do
        result = resource_manager.read_resource('ferrum://user-profiles/dev')
        data = JSON.parse(result[:text])

        expect(data['id']).to eq('dev')
        expect(data['name']).to eq('Dev')
        expect(data['path']).to eq('/home/user/.chrome-dev')
        expect(data).to have_key('usage')
      end
    end

    describe 'bot profiles resource' do
      it 'lists all bot profiles with features' do
        result = resource_manager.read_resource('ferrum://bot-profiles')
        data = JSON.parse(result[:text])

        expect(data['profiles'].count).to eq(1)
        expect(data['total']).to eq(1)
        expect(data['using_botbrowser']).to be true
        expect(data).to have_key('note')
      end

      it 'provides detailed bot profile with anti-detection features' do
        result = resource_manager.read_resource('ferrum://bot-profiles/us')
        data = JSON.parse(result[:text])

        expect(data['id']).to eq('us')
        expect(data['encrypted']).to be true
        expect(data).to have_key('features')
        expect(data['features']).to include(
          'canvas_fingerprinting',
          'webgl_protection',
          'audio_context_hardening',
          'webrtc_leak_prevention'
        )
      end
    end

    describe 'capabilities resource' do
      it 'reports multi-browser and multi-profile capabilities' do
        result = resource_manager.read_resource('ferrum://capabilities')
        data = JSON.parse(result[:text])

        aggregate_failures do
          expect(data['features']['multi_browser']).to be true
          expect(data['features']['user_profiles']).to be true
          expect(data['features']['bot_profiles']).to be true
          expect(data['features']['botbrowser_integration']).to be true

          expect(data['browsers_count']).to eq(2)
          expect(data['user_profiles_count']).to eq(1)
          expect(data['bot_profiles_count']).to eq(1)
        end
      end
    end

    describe 'resource URIs' do
      it 'returns nil for unknown resources' do
        result = resource_manager.read_resource('ferrum://unknown')
        expect(result).to be_nil
      end

      it 'returns nil for non-existent browser' do
        result = resource_manager.read_resource('ferrum://browsers/nonexistent')
        expect(result).to be_nil
      end

      it 'returns nil for non-existent user profile' do
        result = resource_manager.read_resource('ferrum://user-profiles/nonexistent')
        expect(result).to be_nil
      end

      it 'returns nil for non-existent bot profile' do
        result = resource_manager.read_resource('ferrum://bot-profiles/nonexistent')
        expect(result).to be_nil
      end
    end

    describe 'browser with nil path (system browser)' do
      before do
        ENV['BROWSER_SYSTEM'] = 'chrome::System Chrome:Use system Chrome'
      end

      it 'handles browser with nil path correctly' do
        result = resource_manager.read_resource('ferrum://browsers/system')
        data = JSON.parse(result[:text])

        aggregate_failures do
          expect(data['id']).to eq('system')
          expect(data['path']).to be_nil
          expect(data['exists']).to be true # nil path means use system, so exists is true
        end
      end
    end

    describe 'capabilities without multi-browser' do
      before do
        # Clear all custom browsers, should fall back to system browser
        ENV.keys.grep(/^BROWSER_/).each { |key| ENV.delete(key) }
        ENV['BROWSER_HEADLESS'] = 'true' # Keep this one
      end

      it 'reports multi_browser as false when only one browser' do
        config = FerrumMCP::Configuration.new
        manager = FerrumMCP::ResourceManager.new(config)
        result = manager.read_resource('ferrum://capabilities')
        data = JSON.parse(result[:text])

        expect(data['features']['multi_browser']).to be false
        expect(data['browsers_count']).to eq(1)
      end
    end

    describe 'capabilities without profiles' do
      let(:keys) { %w[BROWSER_HEADLESS BROWSER_TIMEOUT] }

      before do
        # Clear all ENV variables and set only browser
        ENV.keys.grep(/^(BROWSER_|USER_PROFILE_|BOT_PROFILE_|BOTBROWSER_)/).each do |key|
          ENV.delete(key) unless keys.include?(key)
        end
        ENV['BROWSER_CHROME'] = 'chrome:/usr/bin/chrome:Chrome:Standard'
        # No user or bot profiles configured
      end

      it 'reports profile features as false when no profiles' do
        config = FerrumMCP::Configuration.new
        manager = FerrumMCP::ResourceManager.new(config)
        result = manager.read_resource('ferrum://capabilities')
        data = JSON.parse(result[:text])

        aggregate_failures do
          expect(data['features']['user_profiles']).to be false
          expect(data['features']['bot_profiles']).to be false
          expect(data['features']['botbrowser_integration']).to be false
          expect(data['user_profiles_count']).to eq(0)
          expect(data['bot_profiles_count']).to eq(0)
        end
      end
    end
  end

  describe 'SessionManager with multi-browser' do
    let(:config) { FerrumMCP::Configuration.new }
    let(:session_manager) { FerrumMCP::SessionManager.new(config) }

    before do
      ENV['BROWSER_CHROME'] = 'chrome:/usr/bin/chrome:Chrome:Standard'
      ENV['BROWSER_BOTBROWSER'] = 'botbrowser:/opt/botbrowser:BotBrowser:Anti-detection'
      ENV['BOT_PROFILE_US'] = '/profiles/us.enc:US:US fingerprint'
    end

    after do
      session_manager.close_all_sessions
    end

    it 'creates sessions with different browsers' do
      chrome_session_id = session_manager.create_session(browser_id: 'chrome')
      bot_session_id = session_manager.create_session(browser_id: 'botbrowser', bot_profile_id: 'us')

      sessions = session_manager.list_sessions

      chrome_session = sessions.find { |s| s[:id] == chrome_session_id }
      bot_session = sessions.find { |s| s[:id] == bot_session_id }

      expect(chrome_session[:browser_type]).to eq('Chrome')
      expect(bot_session[:browser_type]).to eq('BotBrowser (US)')
    end

    it 'maintains isolation between sessions with different browsers' do
      session1_id = session_manager.create_session(browser_id: 'chrome')
      session2_id = session_manager.create_session(browser_id: 'botbrowser')

      expect(session1_id).not_to eq(session2_id)

      session1 = session_manager.get_session(session1_id)
      session2 = session_manager.get_session(session2_id)

      expect(session1.browser_manager).not_to eq(session2.browser_manager)
    end
  end

  describe 'CreateSessionTool with multi-browser' do
    let(:config) { FerrumMCP::Configuration.new }
    let(:session_manager) { FerrumMCP::SessionManager.new(config) }
    let(:create_tool) { FerrumMCP::Tools::CreateSessionTool.new(session_manager) }

    before do
      ENV['BROWSER_CHROME'] = 'chrome:/usr/bin/chrome:Chrome:Standard'
      ENV['BOT_PROFILE_US'] = '/profiles/us.enc:US:US fingerprint'
    end

    after do
      session_manager.close_all_sessions
    end

    it 'accepts browser_id parameter' do
      result = create_tool.execute({ browser_id: 'chrome', headless: true })

      expect(result[:success]).to be true
      expect(result[:data][:options][:browser_id]).to eq('chrome')
    end

    it 'accepts bot_profile_id parameter' do
      result = create_tool.execute({ bot_profile_id: 'us', headless: true })

      expect(result[:success]).to be true
      expect(result[:data][:options][:bot_profile_id]).to eq('us')
    end

    it 'accepts user_profile_id parameter' do
      ENV['USER_PROFILE_DEV'] = '/home/.chrome-dev:Dev:Dev'
      result = create_tool.execute({ user_profile_id: 'dev', headless: true })

      expect(result[:success]).to be true
      expect(result[:data][:options][:user_profile_id]).to eq('dev')
    end

    it 'still supports legacy browser_path parameter' do
      result = create_tool.execute({ browser_path: '/custom/chrome', headless: true })

      expect(result[:success]).to be true
      expect(result[:data][:options][:browser_path]).to eq('/custom/chrome')
    end

    it 'creates session with combined parameters' do
      ENV['USER_PROFILE_DEV'] = '/home/.chrome-dev:Dev:Dev'
      result = create_tool.execute({
                                     browser_id: 'chrome',
                                     user_profile_id: 'dev',
                                     headless: true
                                   })

      expect(result[:success]).to be true
      expect(result[:data][:options][:browser_id]).to eq('chrome')
      expect(result[:data][:options][:user_profile_id]).to eq('dev')
    end
  end
end
