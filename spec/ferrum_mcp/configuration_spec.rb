# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FerrumMCP::Configuration do
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
    it 'returns true when browser_path is nil' do
      config = described_class.new
      config.browser_path = nil
      expect(config.valid?).to be true
    end

    it 'returns true when browser_path exists' do
      config = described_class.new
      config.browser_path = __FILE__ # Use this file as a valid path
      expect(config.valid?).to be true
    end

    it 'returns false when browser_path does not exist' do
      config = described_class.new
      config.browser_path = '/non/existent/path'
      expect(config.valid?).to be false
    end
  end

  describe '#using_botbrowser?' do
    it 'returns false when botbrowser_profile is nil' do
      config = described_class.new
      config.botbrowser_profile = nil
      expect(config.using_botbrowser?).to be false
    end

    it 'returns false when botbrowser_profile is empty' do
      config = described_class.new
      config.botbrowser_profile = ''
      expect(config.using_botbrowser?).to be false
    end

    it 'returns true when botbrowser_profile is set' do
      config = described_class.new
      config.botbrowser_profile = 'default'
      expect(config.using_botbrowser?).to be true
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
