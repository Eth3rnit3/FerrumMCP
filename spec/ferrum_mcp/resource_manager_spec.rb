# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FerrumMCP::ResourceManager do
  let(:preserved_env_keys) { %w[BROWSER_HEADLESS BROWSER_TIMEOUT] }
  let(:config) { FerrumMCP::Configuration.new }
  let(:resource_manager) { described_class.new(config) }

  before do
    # Clean up environment variables
    ENV.keys.grep(/^(BROWSER_|USER_PROFILE_|BOT_PROFILE_|BOTBROWSER_)/).each do |key|
      ENV.delete(key) unless preserved_env_keys.include?(key)
    end
  end

  describe '#resources' do
    it 'returns array of MCP::Resource objects' do
      resources = resource_manager.resources
      expect(resources).to be_an(Array)
      expect(resources).to all(be_a(MCP::Resource))
    end

    it 'includes core resources' do
      resource_uris = resource_manager.resources.map(&:uri)
      expect(resource_uris).to include('ferrum://browsers')
      expect(resource_uris).to include('ferrum://user-profiles')
      expect(resource_uris).to include('ferrum://bot-profiles')
      expect(resource_uris).to include('ferrum://capabilities')
    end

    context 'with multiple browsers configured' do
      before do
        ENV['BROWSER_CHROME'] = 'chrome::Chrome:System Chrome'
        ENV['BROWSER_BOTBROWSER'] = 'botbrowser:/opt/bot:BotBrowser:Anti-detection'
      end

      it 'creates resources for each browser' do
        resource_uris = resource_manager.resources.map(&:uri)
        expect(resource_uris).to include('ferrum://browsers/chrome')
        expect(resource_uris).to include('ferrum://browsers/botbrowser')
      end
    end

    context 'with profiles configured' do
      before do
        ENV['USER_PROFILE_DEV'] = '/home/user/.chrome-dev:Dev:Development profile'
        ENV['BOT_PROFILE_US'] = '/profiles/us.enc:US:US profile'
      end

      it 'creates resources for each profile' do
        resource_uris = resource_manager.resources.map(&:uri)
        expect(resource_uris).to include('ferrum://user-profiles/dev')
        expect(resource_uris).to include('ferrum://bot-profiles/us')
      end
    end
  end

  describe '#read_resource' do
    context 'when reading browsers resource' do
      it 'returns browsers list with expected structure' do
        result = resource_manager.read_resource('ferrum://browsers')
        data = JSON.parse(result[:text])

        aggregate_failures do
          expect(result).to be_a(Hash)
          expect(result[:uri]).to eq('ferrum://browsers')
          expect(result[:mimeType]).to eq('application/json')
          expect(data).to have_key('browsers')
          expect(data).to have_key('default')
          expect(data).to have_key('total')
        end
      end
    end

    context 'when reading browser detail resource' do
      before do
        ENV['BROWSER_CHROME'] = 'chrome::Chrome:System Chrome'
      end

      it 'returns browser details' do
        result = resource_manager.read_resource('ferrum://browsers/chrome')
        expect(result).to be_a(Hash)

        data = JSON.parse(result[:text])
        expect(data['id']).to eq('chrome')
        expect(data['name']).to eq('Chrome')
        expect(data).to have_key('is_default')
        expect(data).to have_key('usage')
      end

      it 'returns nil for non-existent browser' do
        result = resource_manager.read_resource('ferrum://browsers/nonexistent')
        expect(result).to be_nil
      end
    end

    context 'when reading user profiles resource' do
      before do
        ENV['USER_PROFILE_DEV'] = '/home/user/.chrome-dev:Dev:Development profile'
      end

      it 'returns user profiles list' do
        result = resource_manager.read_resource('ferrum://user-profiles')
        expect(result).to be_a(Hash)

        data = JSON.parse(result[:text])
        expect(data).to have_key('profiles')
        expect(data).to have_key('total')
        expect(data['total']).to eq(1)
      end

      it 'returns user profile details' do
        result = resource_manager.read_resource('ferrum://user-profiles/dev')
        expect(result).to be_a(Hash)

        data = JSON.parse(result[:text])
        expect(data['id']).to eq('dev')
        expect(data['name']).to eq('Dev')
        expect(data).to have_key('usage')
      end
    end

    context 'when reading bot profiles resource' do
      before do
        ENV['BOT_PROFILE_US'] = '/profiles/us.enc:US:US profile'
      end

      it 'returns bot profiles list' do
        result = resource_manager.read_resource('ferrum://bot-profiles')
        data = JSON.parse(result[:text])

        aggregate_failures do
          expect(result).to be_a(Hash)
          expect(data).to have_key('profiles')
          expect(data).to have_key('total')
          expect(data).to have_key('using_botbrowser')
          expect(data['total']).to eq(1)
          expect(data['using_botbrowser']).to be true
        end
      end

      it 'returns bot profile details with features' do
        result = resource_manager.read_resource('ferrum://bot-profiles/us')
        data = JSON.parse(result[:text])

        aggregate_failures do
          expect(result).to be_a(Hash)
          expect(data['id']).to eq('us')
          expect(data['encrypted']).to be true
          expect(data).to have_key('features')
          expect(data['features']).to include('canvas_fingerprinting')
          expect(data['features']).to include('webgl_protection')
        end
      end
    end

    context 'when reading capabilities resource' do
      it 'returns server capabilities' do
        result = resource_manager.read_resource('ferrum://capabilities')
        data = JSON.parse(result[:text])

        aggregate_failures do
          expect(result).to be_a(Hash)
          expect(data).to have_key('version')
          expect(data).to have_key('features')
          expect(data).to have_key('transport')
          expect(data['features']).to have_key('session_management')
          expect(data['features']).to have_key('screenshot')
          expect(data['features']).to have_key('botbrowser_integration')
        end
      end
    end

    context 'when reading unknown resource' do
      it 'returns nil' do
        result = resource_manager.read_resource('ferrum://unknown')
        expect(result).to be_nil
      end
    end
  end
end
