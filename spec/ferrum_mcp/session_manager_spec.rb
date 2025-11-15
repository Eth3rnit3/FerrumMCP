# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FerrumMCP::SessionManager do
  let(:config) { FerrumMCP::Configuration.new }
  let(:session_manager) { described_class.new(config) }

  after do
    session_manager.shutdown
  end

  describe '#initialize' do
    it 'creates a session manager' do
      expect(session_manager).to be_a(described_class)
    end

    it 'starts cleanup thread' do
      # Give thread time to start
      sleep 0.1
      expect(session_manager.instance_variable_get(:@cleanup_thread)).to be_alive
    end
  end

  describe '#create_session' do
    it 'creates a new session and returns session_id' do
      session_id = session_manager.create_session
      expect(session_id).to be_a(String)
      expect(session_id).to match(/\A[0-9a-f-]{36}\z/) # UUID format
    end

    it 'creates session with custom options' do
      options = { headless: true, timeout: 120 }
      session_id = session_manager.create_session(options)

      session = session_manager.get_session(session_id)
      expect(session.options[:headless]).to be(true)
      expect(session.options[:timeout]).to eq(120)
    end

    it 'creates multiple independent sessions' do
      session_id1 = session_manager.create_session
      session_id2 = session_manager.create_session

      expect(session_id1).not_to eq(session_id2)
      expect(session_manager.session_count).to eq(2)
    end
  end

  describe '#get_session' do
    it 'returns session by id' do
      session_id = session_manager.create_session
      session = session_manager.get_session(session_id)
      expect(session.id).to eq(session_id)
    end

    it 'raises error when id is nil' do
      expect do
        session_manager.get_session(nil)
      end.to raise_error(ArgumentError, /session_id is required/)
    end

    it 'raises error when id is empty string' do
      expect do
        session_manager.get_session('')
      end.to raise_error(ArgumentError, /session_id is required/)
    end

    it 'returns nil for non-existent session' do
      session = session_manager.get_session('non-existent-id')
      expect(session).to be_nil
    end
  end

  describe '#close_session' do
    it 'closes and removes session' do
      session_id = session_manager.create_session
      expect(session_manager.session_count).to eq(1)

      result = session_manager.close_session(session_id)
      expect(result).to be(true)
      expect(session_manager.session_count).to eq(0)
    end

    it 'returns false for non-existent session' do
      result = session_manager.close_session('non-existent-id')
      expect(result).to be(false)
    end
  end

  describe '#list_sessions' do
    it 'returns empty array when no sessions' do
      sessions = session_manager.list_sessions
      expect(sessions).to eq([])
    end

    it 'lists all active sessions' do
      session_id1 = session_manager.create_session(metadata: { name: 'session1' })
      session_id2 = session_manager.create_session(metadata: { name: 'session2' })

      sessions = session_manager.list_sessions
      expect(sessions.size).to eq(2)
      expect(sessions.map { |s| s[:id] }).to contain_exactly(session_id1, session_id2)
    end
  end

  describe '#with_session' do
    it 'yields browser manager for valid session' do
      session_id = session_manager.create_session

      session_manager.with_session(session_id) do |browser_manager|
        expect(browser_manager).to be_a(FerrumMCP::BrowserManager)
      end
    end

    it 'raises error when id is nil' do
      expect do
        session_manager.with_session(nil) { |_| nil }
      end.to raise_error(ArgumentError, /session_id is required/)
    end

    it 'raises error when id is empty string' do
      expect do
        session_manager.with_session('') { |_| nil }
      end.to raise_error(ArgumentError, /session_id is required/)
    end

    it 'raises error for non-existent session' do
      expect do
        session_manager.with_session('non-existent-id') { |_| nil }
      end.to raise_error(FerrumMCP::SessionError, /Session not found/)
    end

    it 'starts browser if not active', :integration do
      session_id = session_manager.create_session
      session = session_manager.get_session(session_id)

      expect(session.active?).to be(false)

      session_manager.with_session(session_id) do |browser_manager|
        expect(browser_manager.active?).to be(true)
      end

      session.stop
    end
  end

  describe '#close_all_sessions' do
    it 'closes all sessions' do
      session_manager.create_session
      session_manager.create_session

      expect(session_manager.session_count).to eq(2)

      session_manager.close_all_sessions
      expect(session_manager.session_count).to eq(0)
    end
  end

  describe '#session_timeout=' do
    it 'sets custom session timeout' do
      session_manager.session_timeout = 300
      timeout = session_manager.instance_variable_get(:@session_timeout)
      expect(timeout).to eq(300)
    end
  end

  describe 'cleanup thread' do
    it 'cleans up idle sessions' do
      # Set very short timeout for testing
      session_manager.session_timeout = 0.5

      session_manager.create_session
      expect(session_manager.session_count).to eq(1)

      # Wait for cleanup (cleanup runs every 5 minutes by default, but we can trigger it manually)
      # For testing, we'll access the private method
      sleep 0.6
      session_manager.send(:cleanup_idle_sessions)

      # Session should be cleaned up
      expect(session_manager.session_count).to eq(0)
    end

    it 'cleans up all idle sessions including those created manually' do
      session_manager.session_timeout = 0.5

      session_id = session_manager.create_session
      session = session_manager.get_session(session_id)

      # Manually set last_used_at to the past
      session.instance_variable_set(:@last_used_at, Time.now - 10)

      expect(session_manager.session_count).to eq(1)
      session_manager.send(:cleanup_idle_sessions)

      # Session should be cleaned up
      expect(session_manager.session_count).to eq(0)
    end
  end

  describe '#shutdown' do
    it 'stops cleanup thread and closes all sessions' do
      session_manager.create_session
      session_manager.create_session

      expect(session_manager.session_count).to be > 0

      session_manager.shutdown

      expect(session_manager.session_count).to eq(0)
      expect(session_manager.instance_variable_get(:@cleanup_thread)).to be_nil
    end
  end

  describe 'thread safety' do
    it 'handles concurrent session creation' do
      threads = Array.new(10) do
        Thread.new { session_manager.create_session }
      end

      session_ids = threads.map(&:value)

      expect(session_ids.uniq.size).to eq(10) # All unique IDs
      expect(session_manager.session_count).to eq(10)
    end

    it 'handles concurrent session access' do
      session_id = session_manager.create_session
      results = []

      threads = Array.new(5) do
        Thread.new do
          session_manager.with_session(session_id) do |_|
            results << Thread.current.object_id
            sleep 0.01
          end
        end
      end

      threads.each(&:join)
      expect(results.size).to eq(5)
    end
  end
end
