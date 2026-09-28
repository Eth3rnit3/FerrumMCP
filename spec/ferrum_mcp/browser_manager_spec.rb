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
    # --disable-web-security turns site isolation off entirely, which puts
    # Cloudflare's frame back in the page process where CDP clicks are
    # rejected; --enable-automation flags the browser as automated.
    it 'launches Chrome without the Ferrum defaults that give automation away' do
      manager_for(headless: false, browser_options: {}).start

      expect(launch_kwargs[:ignore_default_browser_options]).to be true
      expect(launch_kwargs[:browser_options].keys).not_to include('disable-web-security', 'enable-automation')
    end

    it 'keeps the rest of the Ferrum defaults' do
      manager_for(headless: false, browser_options: {}).start

      expect(launch_kwargs[:browser_options]).to include('no-first-run' => nil, 'mute-audio' => nil)
      expect(launch_kwargs[:browser_options]).not_to have_key('headless')
    end

    context 'when headless' do
      before { allow(described_class).to receive(:chrome_major_version).and_return(154) }

      # Cloudflare rejects the "HeadlessChrome/x" user agent outright
      it 'presents the regular Chrome user agent of the installed version' do
        manager_for(headless: true, browser_options: {}).start

        user_agent = launch_kwargs[:browser_options]['user-agent']
        expect(user_agent).to include('Chrome/154.0.0.0').and start_with('Mozilla/5.0 (')
        expect(user_agent).not_to include('Headless')
      end

      it 'reports a screen larger than the 800x600 headless default' do
        manager_for(headless: true, browser_options: {}).start

        expect(launch_kwargs[:browser_options]['screen-info']).to eq('{1920x1080}')
      end

      it 'keeps a user agent chosen by the session' do
        manager_for(headless: true, browser_options: { 'user-agent' => 'Custom/1.0' }).start

        expect(launch_kwargs[:browser_options]['user-agent']).to eq('Custom/1.0')
      end

      it 'leaves the user agent alone when the Chrome version is unknown' do
        allow(described_class).to receive(:chrome_major_version).and_return(nil)
        manager_for(headless: true, browser_options: {}).start

        expect(launch_kwargs[:browser_options]).not_to have_key('user-agent')
      end
    end

    it 'does not disguise a visible browser' do
      manager_for(headless: false, browser_options: {}).start

      expect(launch_kwargs[:browser_options].keys).not_to include('user-agent', 'screen-info')
    end

    it 'still runs headless when asked to' do
      manager_for(headless: true, browser_options: {}).start

      expect(launch_kwargs[:browser_options]).to have_key('headless')
    end

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
