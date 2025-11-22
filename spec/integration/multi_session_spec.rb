# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Multi-Session Integration' do
  let(:config) { FerrumMCP::Configuration.new }
  let(:session_manager) { FerrumMCP::SessionManager.new(config) }

  after do
    session_manager.shutdown
  end

  describe 'concurrent sessions' do
    it 'handles multiple independent sessions simultaneously' do
      # Create 3 concurrent sessions
      session_ids = 3.times.map { session_manager.create_session(headless: true) }

      # Verify all sessions are active
      expect(session_manager.session_count).to eq(3)

      # Navigate each session to different pages
      session_manager.with_session(session_ids[0]) do |browser_manager|
        browser_manager.browser.goto(test_url('/test'))
      end

      session_manager.with_session(session_ids[1]) do |browser_manager|
        browser_manager.browser.goto(test_url('/test/page2'))
      end

      session_manager.with_session(session_ids[2]) do |browser_manager|
        browser_manager.browser.goto(test_url('/test'))
      end

      # Verify each session has correct URL
      session_manager.with_session(session_ids[0]) do |browser_manager|
        expect(browser_manager.browser.current_url).to include('/test')
      end

      session_manager.with_session(session_ids[1]) do |browser_manager|
        expect(browser_manager.browser.current_url).to include('/page2')
      end

      session_manager.with_session(session_ids[2]) do |browser_manager|
        expect(browser_manager.browser.current_url).to include('/test')
      end
    end

    it 'maintains session isolation' do
      # Create 2 sessions
      session1 = session_manager.create_session(headless: true)
      session2 = session_manager.create_session(headless: true)

      # Set different content in each session
      session_manager.with_session(session1) do |browser_manager|
        browser_manager.browser.goto(test_url('/test'))
        browser_manager.browser.execute(<<~JS)
          document.getElementById('title').textContent = 'Session 1';
        JS
      end

      session_manager.with_session(session2) do |browser_manager|
        browser_manager.browser.goto(test_url('/test'))
        browser_manager.browser.execute(<<~JS)
          document.getElementById('title').textContent = 'Session 2';
        JS
      end

      # Verify each session retained its own content
      session_manager.with_session(session1) do |browser_manager|
        title = browser_manager.browser.at_css('#title').text
        expect(title).to eq('Session 1')
      end

      session_manager.with_session(session2) do |browser_manager|
        title = browser_manager.browser.at_css('#title').text
        expect(title).to eq('Session 2')
      end
    end

    it 'handles session cleanup correctly' do
      # Create sessions
      session_ids = 5.times.map { session_manager.create_session(headless: true) }
      expect(session_manager.session_count).to eq(5)

      # Close 3 sessions
      session_ids[0..2].each { |sid| session_manager.close_session(sid) }

      # Verify count decreased
      expect(session_manager.session_count).to eq(2)

      # Verify remaining sessions are still accessible
      session_manager.with_session(session_ids[3]) do |browser_manager|
        expect(browser_manager.active?).to be true
      end
    end
  end

  describe 'session limit enforcement' do
    it 'respects MAX_CONCURRENT_SESSIONS limit' do
      # Get the configured limit
      max_sessions = config.max_sessions

      # Create sessions up to the limit
      session_ids = max_sessions.times.map { session_manager.create_session(headless: true) }
      expect(session_manager.session_count).to eq(max_sessions)

      # Attempt to exceed limit should raise error
      expect do
        session_manager.create_session(headless: true)
      end.to raise_error(FerrumMCP::SessionError, /Maximum concurrent sessions limit reached/)

      # Verify count hasn't changed
      expect(session_manager.session_count).to eq(max_sessions)

      # Close one session
      session_manager.close_session(session_ids.first)

      # Should now be able to create a new session
      new_session = session_manager.create_session(headless: true)
      expect(new_session).to be_a(String)
      expect(session_manager.session_count).to eq(max_sessions)
    end
  end

  describe 'concurrent tool execution' do
    it 'executes tools concurrently across sessions' do
      # Create multiple sessions
      session_ids = 3.times.map do
        sid = session_manager.create_session(headless: true)
        session_manager.with_session(sid) do |browser_manager|
          browser_manager.browser.goto(test_url('/test'))
        end
        sid
      end

      # Execute screenshot tool concurrently
      screenshots = session_ids.map do |sid|
        Thread.new do
          session_manager.with_session(sid) do |browser_manager|
            tool = FerrumMCP::Tools::ScreenshotTool.new(browser_manager)
            tool.execute({})
          end
        end
      end.map(&:value)

      # Verify all screenshots succeeded
      expect(screenshots).to all(satisfy { |r| r[:success] == true })
      expect(screenshots).to all(have_key(:data))
    end

    it 'handles errors in one session without affecting others' do
      # Create 3 sessions
      session_ids = 3.times.map { session_manager.create_session(headless: true) }

      # Navigate first two sessions successfully
      session_manager.with_session(session_ids[0]) do |browser_manager|
        browser_manager.browser.goto(test_url('/test'))
      end

      session_manager.with_session(session_ids[1]) do |browser_manager|
        browser_manager.browser.goto(test_url('/test'))
      end

      # Third session will have an error (invalid selector)
      result = session_manager.with_session(session_ids[2]) do |browser_manager|
        browser_manager.browser.goto(test_url('/test'))
        tool = FerrumMCP::Tools::ClickTool.new(browser_manager)
        tool.execute({ selector: '#nonexistent-element' })
      end

      # Verify error in third session
      expect(result[:success]).to be false

      # Verify first two sessions are still functional
      session_manager.with_session(session_ids[0]) do |browser_manager|
        expect(browser_manager.active?).to be true
        expect(browser_manager.browser.current_url).to include('/test')
      end

      session_manager.with_session(session_ids[1]) do |browser_manager|
        expect(browser_manager.active?).to be true
        expect(browser_manager.browser.current_url).to include('/test')
      end
    end
  end

  describe 'session info and listing' do
    it 'provides accurate session information' do
      # Create sessions with different options
      session1 = session_manager.create_session(headless: true, timeout: 30)
      session2 = session_manager.create_session(headless: false, timeout: 60)

      # Get session info
      sessions = session_manager.list_sessions
      expect(sessions.length).to eq(2)

      # Verify session info structure
      sessions.each do |info|
        expect(info).to have_key(:id)
        expect(info).to have_key(:created_at)
        expect(info).to have_key(:last_used_at)
        expect(info).to have_key(:browser_type)
      end
    end
  end
end
