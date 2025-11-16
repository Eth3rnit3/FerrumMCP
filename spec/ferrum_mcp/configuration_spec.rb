# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FerrumMCP::Configuration do
  let(:preserved_env_keys) { %w[BROWSER_HEADLESS BROWSER_TIMEOUT] }

  # Clean up environment variables before each test
  before do
    # Remove all browser, profile, and legacy config env vars
    ENV.keys.grep(/^(BROWSER_|USER_PROFILE_|BOT_PROFILE_|BOTBROWSER_)/).each do |key|
      ENV.delete(key) unless preserved_env_keys.include?(key)
    end
  end

  describe '#initialize' do
    it 'creates a configuration with default transport' do
      config = described_class.new
      expect(config.transport).to eq('http')
    end

    it 'accepts custom transport option' do
      config = described_class.new(transport: 'stdio')
      expect(config.transport).to eq('stdio')
    end

    it 'loads environment variables' do
      ENV['BROWSER_HEADLESS'] = 'true'
      ENV['BROWSER_TIMEOUT'] = '120'
      ENV['MCP_SERVER_HOST'] = '0.0.0.0'
      ENV['MCP_SERVER_PORT'] = '4000'

      config = described_class.new

      expect(config.headless).to be true
      expect(config.timeout).to eq(120)
      expect(config.server_host).to eq('0.0.0.0')
      expect(config.server_port).to eq(4000)
    end
  end

  describe '#valid?' do
    it 'returns true when using system Chrome (no custom browsers)' do
      config = described_class.new
      expect(config.valid?).to be true
    end

    it 'returns true when browser paths exist' do
      ENV['BROWSER_TEST'] = "chrome:#{__FILE__}:Test:Test browser"
      config = described_class.new
      expect(config.valid?).to be true
    end

    it 'returns false when browser path does not exist' do
      ENV['BROWSER_INVALID'] = 'chrome:/non/existent/path:Invalid:Invalid browser'
      config = described_class.new
      expect(config.valid?).to be false
    end
  end

  describe '#browsers' do
    it 'loads browsers from environment variables' do
      ENV['BROWSER_CHROME'] = 'chrome:/usr/bin/google-chrome:Google Chrome:Standard browser'
      ENV['BROWSER_BOTBROWSER'] = 'botbrowser:/opt/botbrowser:BotBrowser:Anti-detection'

      config = described_class.new
      expect(config.browsers.length).to eq(2)
      expect(config.browsers.first.id).to eq('chrome')
      expect(config.browsers.first.type).to eq('chrome')
    end

    it 'creates system browser when no browsers configured' do
      config = described_class.new
      expect(config.browsers.length).to eq(1)
      expect(config.browsers.first.id).to eq('system')
      expect(config.browsers.first.type).to eq('chrome')
    end

    it 'supports legacy BROWSER_PATH' do
      ENV['BROWSER_PATH'] = '/usr/bin/google-chrome'
      config = described_class.new
      browser = config.browsers.find { |b| b.id == 'default' }
      expect(browser).not_to be_nil
      expect(browser.path).to eq('/usr/bin/google-chrome')
    end
  end

  describe '#user_profiles' do
    it 'loads user profiles from environment variables' do
      ENV['USER_PROFILE_DEV'] = '/home/user/.chrome-dev:Development:Dev profile'
      ENV['USER_PROFILE_TEST'] = '/home/user/.chrome-test:Testing:Test profile'

      config = described_class.new
      expect(config.user_profiles.length).to eq(2)
      expect(config.user_profiles.first.id).to eq('dev')
      expect(config.user_profiles.first.path).to eq('/home/user/.chrome-dev')
    end

    it 'returns empty array when no profiles configured' do
      config = described_class.new
      expect(config.user_profiles).to be_empty
    end
  end

  describe '#bot_profiles' do
    it 'loads bot profiles from environment variables' do
      ENV['BOT_PROFILE_US'] = '/profiles/us.enc:US Profile:US fingerprint'
      ENV['BOT_PROFILE_EU'] = '/profiles/eu.enc:EU Profile:EU fingerprint'

      config = described_class.new
      expect(config.bot_profiles.length).to eq(2)
      expect(config.bot_profiles.first.id).to eq('us')
      expect(config.bot_profiles.first.encrypted).to be true
    end

    it 'supports legacy BOTBROWSER_PROFILE' do
      ENV['BOTBROWSER_PROFILE'] = '/profiles/default.enc'
      config = described_class.new
      profile = config.bot_profiles.find { |p| p.id == 'default' }
      expect(profile).not_to be_nil
      expect(profile.path).to eq('/profiles/default.enc')
    end

    it 'returns empty array when no profiles configured' do
      config = described_class.new
      expect(config.bot_profiles).to be_empty
    end
  end

  describe '#using_botbrowser?' do
    it 'returns false when no bot profiles configured' do
      config = described_class.new
      expect(config.using_botbrowser?).to be false
    end

    it 'returns true when bot profiles are configured' do
      ENV['BOT_PROFILE_TEST'] = '/profiles/test.enc:Test:Test profile'
      config = described_class.new
      expect(config.using_botbrowser?).to be true
    end
  end

  describe '#find_browser' do
    it 'finds browser by id' do
      ENV['BROWSER_CHROME'] = 'chrome::Chrome:System Chrome'
      config = described_class.new
      browser = config.find_browser('chrome')
      expect(browser).not_to be_nil
      expect(browser.id).to eq('chrome')
    end

    it 'returns nil for non-existent browser' do
      config = described_class.new
      expect(config.find_browser('nonexistent')).to be_nil
    end
  end

  describe '#find_user_profile' do
    it 'finds user profile by id' do
      ENV['USER_PROFILE_DEV'] = '/home/user/.chrome-dev:Dev:Development'
      config = described_class.new
      profile = config.find_user_profile('dev')
      expect(profile).not_to be_nil
      expect(profile.id).to eq('dev')
    end

    it 'returns nil for non-existent profile' do
      config = described_class.new
      expect(config.find_user_profile('nonexistent')).to be_nil
    end
  end

  describe '#find_bot_profile' do
    it 'finds bot profile by id' do
      ENV['BOT_PROFILE_US'] = '/profiles/us.enc:US:US Profile'
      config = described_class.new
      profile = config.find_bot_profile('us')
      expect(profile).not_to be_nil
      expect(profile.id).to eq('us')
    end

    it 'returns nil for non-existent profile' do
      config = described_class.new
      expect(config.find_bot_profile('nonexistent')).to be_nil
    end
  end

  describe '#logger' do
    it 'creates a logger' do
      config = described_class.new
      expect(config.logger).to be_a(Logger)
    end

    it 'uses the configured log level' do
      config = described_class.new
      config.log_level = :warn
      logger = config.logger
      expect(logger.level).to eq(Logger::WARN)
    end

    it 'creates log file successfully' do
      config = described_class.new(transport: 'stdio')

      # Create the logger which should create the directory and file
      logger = config.logger
      expect(logger).to be_a(Logger)

      # Log something to ensure the file gets created
      logger.info 'test log message'

      # Verify we can log without errors
      expect { logger.info 'another test' }.not_to raise_error
    end

    it 'writes logs to file only (no console output)' do
      config = described_class.new
      logger = config.logger

      # Capture stdout/stderr
      original_stdout = $stdout
      original_stderr = $stderr
      # rubocop:disable RSpec/ExpectOutput
      $stdout = StringIO.new
      $stderr = StringIO.new
      # rubocop:enable RSpec/ExpectOutput

      begin
        logger.info 'test message'
        $stdout.rewind
        $stderr.rewind

        # Verify no output to console
        expect($stdout.read).to be_empty
        expect($stderr.read).to be_empty
      ensure
        # rubocop:disable RSpec/ExpectOutput
        $stdout = original_stdout
        $stderr = original_stderr
        # rubocop:enable RSpec/ExpectOutput
      end
    end
  end
end
