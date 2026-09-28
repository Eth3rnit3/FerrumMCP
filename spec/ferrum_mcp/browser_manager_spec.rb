# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

# Unit tests: Ferrum::Browser is stubbed so no Chrome process is launched.
RSpec.describe FerrumMCP::BrowserManager do
  let(:config) { FerrumMCP::Configuration.new }
  let(:fake_browser) { instance_double(Ferrum::Browser, quit: nil) }
  let(:launch_kwargs) { {} }

  before do
    allow(Ferrum::Browser).to receive(:new) do |**kwargs|
      launch_kwargs.merge!(kwargs)
      fake_browser
    end
  end

  def manager_for(options)
    FerrumMCP::Session.new(config: config, options: options).browser_manager
  end

  describe '#start' do
    it 'passes session browser_options through to Ferrum' do
      manager_for(headless: true, browser_options: { 'window-size' => '800,600' }).start

      expect(launch_kwargs[:browser_options]).to include('window-size' => '800,600')
    end

    it 'strips leading dashes from option keys because Ferrum adds them itself' do
      manager_for(headless: true, browser_options: { '--window-size' => '800,600' }).start

      expect(launch_kwargs[:browser_options]).to include('window-size' => '800,600')
      expect(launch_kwargs[:browser_options].keys).not_to include('--window-size')
    end

    it 'accepts symbol keys for browser_options' do
      manager_for(headless: true, browser_options: { lang: 'fr-FR' }).start

      expect(launch_kwargs[:browser_options]).to include('lang' => 'fr-FR')
    end

    it 'keeps anti-automation defaults alongside custom options' do
      manager_for(headless: true, browser_options: { 'window-size' => '800,600' }).start

      expect(launch_kwargs[:browser_options]).to include('disable-blink-features' => 'AutomationControlled')
    end

    it 'lets custom options override defaults' do
      manager_for(headless: true, browser_options: { 'disable-gpu' => 'false' }).start

      expect(launch_kwargs[:browser_options]['disable-gpu']).to eq('false')
    end

    it 'passes the user profile directory as user-data-dir' do
      profile_dir = Dir.mktmpdir('ferrum-profile')
      ENV['USER_PROFILE_DEV'] = "#{profile_dir}:Development:Dev profile"

      manager_for(headless: true, user_profile_id: 'dev').start

      expect(launch_kwargs[:browser_options]).to include('user-data-dir' => profile_dir)
    ensure
      FileUtils.rm_rf(profile_dir) if profile_dir
    end

    it 'does not set user-data-dir when no profile is requested' do
      manager_for(headless: true).start

      expect(launch_kwargs[:browser_options]).not_to have_key('user-data-dir')
    end

    it 'passes headless and timeout to Ferrum' do
      manager_for(headless: true, timeout: 42).start

      expect(launch_kwargs).to include(headless: true, timeout: 42)
    end

    it 'does not pass browser_path when using the system browser' do
      manager_for(headless: true).start

      expect(launch_kwargs).not_to have_key(:browser_path)
    end

    it 'wraps Ferrum failures in BrowserError' do
      allow(Ferrum::Browser).to receive(:new).and_raise(Ferrum::ProcessTimeoutError.new(5, ''))

      expect { manager_for(headless: true).start }.to raise_error(FerrumMCP::BrowserError, /Failed to start browser/)
    end
  end

  describe '#stop' do
    it 'quits the browser and clears state' do
      manager = manager_for(headless: true)
      manager.start
      manager.stop

      expect(fake_browser).to have_received(:quit)
      expect(manager.active?).to be(false)
    end
  end
end
