# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FerrumMCP::Session do
  let(:config) { FerrumMCP::Configuration.new }
  let(:options) { {} }
  let(:session) { described_class.new(config: config, options: options) }

  describe '#initialize' do
    it 'generates a unique ID' do
      session1 = described_class.new(config: config, options: {})
      session2 = described_class.new(config: config, options: {})

      expect(session1.id).not_to eq(session2.id)
      expect(session1.id).to match(/\A[0-9a-f-]{36}\z/) # UUID format
    end

    it 'creates a browser manager' do
      expect(session.browser_manager).to be_a(FerrumMCP::BrowserManager)
    end

    it 'sets timestamps' do
      expect(session.created_at).to be_a(Time)
      expect(session.last_used_at).to be_a(Time)
    end

    context 'with custom options' do
      let(:options) do
        {
          headless: true,
          timeout: 120,
          metadata: { user: 'test', project: 'rspec' }
        }
      end

      it 'stores options' do
        expect(session.options[:headless]).to eq(true)
        expect(session.options[:timeout]).to eq(120)
      end

      it 'stores metadata' do
        expect(session.metadata).to eq({ user: 'test', project: 'rspec' })
      end
    end
  end

  describe '#with_browser' do
    it 'yields the browser manager' do
      expect { |b| session.with_browser(&b) }.to yield_with_args(session.browser_manager)
    end

    it 'updates last_used_at' do
      original_time = session.last_used_at
      sleep 0.01 # Small sleep to ensure time difference
      session.with_browser { |_| nil }
      expect(session.last_used_at).to be > original_time
    end

    it 'is thread-safe' do
      results = []
      threads = 10.times.map do
        Thread.new do
          session.with_browser do |_|
            results << Thread.current.object_id
            sleep 0.01
          end
        end
      end

      threads.each(&:join)
      expect(results.size).to eq(10)
    end
  end

  describe '#active?' do
    it 'returns false when browser is not started' do
      expect(session.active?).to eq(false)
    end

    it 'returns true after starting browser', :integration do
      session.start
      expect(session.active?).to eq(true)
      session.stop
    end
  end

  describe '#start and #stop', :integration do
    it 'starts and stops the browser' do
      expect(session.active?).to eq(false)

      session.start
      expect(session.active?).to eq(true)

      session.stop
      expect(session.active?).to eq(false)
    end
  end

  describe '#idle?' do
    it 'returns false for recently used session' do
      session.with_browser { |_| nil }
      expect(session.idle?(60)).to eq(false)
    end

    it 'returns true for idle session' do
      # Manually set last_used_at to the past
      session.instance_variable_set(:@last_used_at, Time.now - 120)
      expect(session.idle?(60)).to eq(true)
    end
  end

  describe '#info' do
    it 'returns session information' do
      info = session.info

      expect(info).to include(
        :id,
        :active,
        :created_at,
        :last_used_at,
        :idle_seconds,
        :metadata,
        :browser_type,
        :options
      )

      expect(info[:id]).to eq(session.id)
      expect(info[:active]).to eq(false)
      expect(info[:browser_type]).to eq('System Chrome/Chromium')
    end

    context 'with BotBrowser profile' do
      let(:options) { { botbrowser_profile: '/fake/profile/path' } }

      it 'identifies as BotBrowser' do
        info = session.info
        expect(info[:browser_type]).to eq('BotBrowser')
      end
    end

    context 'with custom browser path' do
      let(:options) { { browser_path: '/custom/chrome/path' } }

      it 'identifies as custom Chrome' do
        info = session.info
        expect(info[:browser_type]).to eq('Custom Chrome/Chromium')
      end
    end
  end
end
