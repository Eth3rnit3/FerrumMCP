# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FerrumMCP::Tools::AcceptCookiesTool do
  let(:config) { FerrumMCP::Configuration.new }
  let(:session_manager) { FerrumMCP::SessionManager.new(config) }

  after(:each) do
    # Cleanup all sessions
    session_manager.shutdown
  end

  # Helper to execute tool within session context
  def execute_tool_in_session(session_id, params)
    session_manager.with_session(session_id) do |browser_manager|
      tool = described_class.new(browser_manager)
      tool.execute(params)
    end
  end

  describe '.tool_name' do
    it 'returns accept_cookies' do
      expect(described_class.tool_name).to eq('accept_cookies')
    end
  end

  describe '.description' do
    it 'returns a description' do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).to include('cookie')
    end
  end

  describe '.input_schema' do
    it 'includes session_id as required' do
      schema = described_class.input_schema
      expect(schema[:required]).to include('session_id')
    end

    it 'includes wait parameter with default' do
      schema = described_class.input_schema
      properties = schema[:properties]

      expect(properties).to have_key(:session_id)
      expect(properties).to have_key(:wait)
      expect(properties[:wait][:default]).to eq(3)
    end
  end

  describe '#execute' do
    context 'when banner has ID-based detection' do
      it 'finds and accepts cookie banner by ID' do
        sid = setup_session_with_fixture(session_manager, 'banner_with_id.html', subdir: 'cookies')

        result = execute_tool_in_session(sid, { session_id: sid, wait: 0 })

        expect(result[:success]).to be true
        expect(result[:data][:message]).to match(/cookie consent accepted/i)
        expect(element_exists?(session_manager, sid, '#banner-accepted')).to be true
      end
    end

    context 'when banner has class-based detection' do
      it 'finds and accepts cookie banner by class' do
        sid = setup_session_with_fixture(session_manager, 'banner_with_class.html', subdir: 'cookies')

        result = execute_tool_in_session(sid, { session_id: sid, wait: 0 })

        expect(result[:success]).to be true
        expect(result[:data][:message]).to match(/cookie consent accepted/i)
        expect(element_exists?(session_manager, sid, '#banner-accepted')).to be true
      end
    end

    context 'when banner requires text-based button detection' do
      it 'finds and clicks button by text content' do
        sid = setup_session_with_fixture(session_manager, 'banner_with_text.html', subdir: 'cookies')

        result = execute_tool_in_session(sid, { session_id: sid, wait: 0 })

        expect(result[:success]).to be true
        expect(result[:data][:message]).to match(/cookie consent accepted/i)
        expect(element_exists?(session_manager, sid, '#banner-accepted')).to be true
      end
    end

    context 'when banner has ARIA attributes' do
      it 'finds and accepts cookie banner by ARIA labels' do
        sid = setup_session_with_fixture(session_manager, 'banner_with_aria.html', subdir: 'cookies')

        result = execute_tool_in_session(sid, { session_id: sid, wait: 0 })

        expect(result[:success]).to be true
        expect(result[:data][:message]).to match(/cookie consent accepted/i)
        expect(element_exists?(session_manager, sid, '#banner-accepted')).to be true
      end
    end

    context 'when banner has multilingual text (French)' do
      it 'finds and accepts cookie banner with French text' do
        sid = setup_session_with_fixture(session_manager, 'banner_multilingual.html', subdir: 'cookies')

        result = execute_tool_in_session(sid, { session_id: sid, wait: 0 })

        expect(result[:success]).to be true
        expect(result[:data][:message]).to match(/cookie consent accepted/i)
        expect(element_exists?(session_manager, sid, '#banner-accepted')).to be true
      end
    end

    context 'when no cookie banner is present' do
      it 'returns error when no banner found' do
        sid = setup_session_with_fixture(session_manager, 'no_banner.html', subdir: 'cookies')

        result = execute_tool_in_session(sid, { session_id: sid, wait: 0 })

        expect(result[:success]).to be false
        expect(result[:error]).to match(/no.*cookie.*consent.*banner/i)
      end
    end

    context 'when session does not exist' do
      it 'raises SessionError' do
        expect do
          execute_tool_in_session('invalid-session', { session_id: 'invalid-session', wait: 0 })
        end.to raise_error(FerrumMCP::SessionError)
      end
    end
  end

  describe 'performance' do
    it 'completes within reasonable time' do
      sid = setup_session_with_fixture(session_manager, 'banner_with_id.html', subdir: 'cookies')

      start_time = Time.now
      execute_tool_in_session(sid, { session_id: sid, wait: 0 })
      duration = Time.now - start_time

      # Should complete in less than 10 seconds
      expect(duration).to be < 10
    end
  end

  describe 'integration scenarios' do
    it 'works with multiple consecutive calls' do
      sid = setup_session_with_fixture(session_manager, 'banner_with_id.html', subdir: 'cookies')

      # First call should accept banner
      result1 = execute_tool_in_session(sid, { session_id: sid, wait: 0 })
      expect(result1[:success]).to be true
      expect(result1[:data][:message]).to match(/cookie consent accepted/i)

      # Second call should report no banner (already accepted)
      result2 = execute_tool_in_session(sid, { session_id: sid, wait: 0 })
      expect(result2[:success]).to be false
      expect(result2[:error]).to match(/no.*cookie.*consent.*banner/i)
    end
  end
end
