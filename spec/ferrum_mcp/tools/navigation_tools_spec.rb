# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Navigation Tools' do
  let(:config) { FerrumMCP::Configuration.new }
  let(:session_manager) { FerrumMCP::SessionManager.new(config) }

  after do
    session_manager.shutdown
  end

  # Helper to execute tool within session context
  def execute_tool_in_session(tool_class, session_id, params)
    session_manager.with_session(session_id) do |browser_manager|
      tool = tool_class.new(browser_manager)
      tool.execute(params)
    end
  end

  describe FerrumMCP::Tools::NavigateTool do
    describe '.tool_name' do
      it 'returns navigate' do
        expect(described_class.tool_name).to eq('navigate')
      end
    end

    describe '.description' do
      it 'returns a description' do
        expect(described_class.description).to be_a(String)
        expect(described_class.description).to include('Navigate')
      end
    end

    describe '.input_schema' do
      it 'includes session_id and url as required' do
        schema = described_class.input_schema
        expect(schema[:required]).to include('session_id', 'url')
      end
    end

    describe '#execute' do
      it 'navigates to a URL successfully' do
        sid = session_manager.create_session(headless: true)

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, url: test_url('/fixtures/navigation/page1') }
        )

        expect(result[:success]).to be true
        expect(result[:data][:url]).to include('/fixtures/navigation/page1')
        expect(result[:data][:title]).to eq('Navigation Test - Page 1')

        # Verify we're on the correct page
        session_manager.with_session(sid) do |browser_manager|
          expect(browser_manager.browser.current_url).to include('/fixtures/navigation/page1')
          expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('1')
        end
      end

      it 'navigates to different pages sequentially' do
        sid = session_manager.create_session(headless: true)

        # Navigate to page 1
        execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, url: test_url('/fixtures/navigation/page1') }
        )

        session_manager.with_session(sid) do |browser_manager|
          expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('1')
        end

        # Navigate to page 2
        execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, url: test_url('/fixtures/navigation/page2') }
        )

        session_manager.with_session(sid) do |browser_manager|
          expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('2')
        end
      end

      it 'handles invalid URLs gracefully' do
        sid = session_manager.create_session(headless: true)

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, url: 'not-a-valid-url' }
        )

        expect(result[:success]).to be false
        expect(result[:error]).to be_a(String)
      end

      it 'raises SessionError when session does not exist' do
        expect do
          execute_tool_in_session(
            described_class,
            'invalid-session',
            { session_id: 'invalid-session', url: 'http://example.com' }
          )
        end.to raise_error(FerrumMCP::SessionError)
      end
    end
  end

  describe FerrumMCP::Tools::GoBackTool do
    describe '.tool_name' do
      it 'returns go_back' do
        expect(described_class.tool_name).to eq('go_back')
      end
    end

    describe '#execute' do
      it 'navigates back in browser history' do
        sid = setup_session_with_fixture(session_manager, 'page1.html', subdir: 'navigation')

        # Navigate to page 2
        session_manager.with_session(sid) do |browser_manager|
          browser_manager.browser.at_css('#link-to-page2').click
          sleep 0.5 # Wait for navigation
        end

        # Verify we're on page 2
        session_manager.with_session(sid) do |browser_manager|
          expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('2')
        end

        # Go back
        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid }
        )

        expect(result[:success]).to be true
        expect(result[:data][:url]).to include('/fixtures/navigation/page1')

        # Verify we're back on page 1
        session_manager.with_session(sid) do |browser_manager|
          expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('1')
        end
      end

      it 'works with multiple back navigations' do
        sid = setup_session_with_fixture(session_manager, 'page1.html', subdir: 'navigation')

        # Navigate page1 -> page2 -> page3
        session_manager.with_session(sid) do |browser_manager|
          browser_manager.browser.at_css('#link-to-page2').click
          sleep 0.5
          browser_manager.browser.at_css('#link-to-page3').click
          sleep 0.5
          expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('3')
        end

        # Go back to page 2
        execute_tool_in_session(described_class, sid, { session_id: sid })
        session_manager.with_session(sid) do |browser_manager|
          expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('2')
        end

        # Go back to page 1
        execute_tool_in_session(described_class, sid, { session_id: sid })
        session_manager.with_session(sid) do |browser_manager|
          expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('1')
        end
      end

      it 'handles when there is no history to go back' do
        sid = setup_session_with_fixture(session_manager, 'page1.html', subdir: 'navigation')

        # Try to go back on first page (no history)
        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid }
        )

        # Should still succeed but stay on same page
        expect(result[:success]).to be true
      end
    end
  end

  describe FerrumMCP::Tools::GoForwardTool do
    describe '.tool_name' do
      it 'returns go_forward' do
        expect(described_class.tool_name).to eq('go_forward')
      end
    end

    describe '#execute' do
      it 'navigates forward in browser history' do
        sid = setup_session_with_fixture(session_manager, 'page1.html', subdir: 'navigation')

        # Navigate to page 2
        session_manager.with_session(sid) do |browser_manager|
          browser_manager.browser.at_css('#link-to-page2').click
          sleep 0.5
        end

        # Go back to page 1
        execute_tool_in_session(FerrumMCP::Tools::GoBackTool, sid, { session_id: sid })

        session_manager.with_session(sid) do |browser_manager|
          expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('1')
        end

        # Go forward to page 2
        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid }
        )

        expect(result[:success]).to be true
        expect(result[:data][:url]).to include('/fixtures/navigation/page2')

        session_manager.with_session(sid) do |browser_manager|
          expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('2')
        end
      end

      it 'works with multiple forward navigations' do
        sid = setup_session_with_fixture(session_manager, 'page1.html', subdir: 'navigation')

        # Build history: page1 -> page2 -> page3
        session_manager.with_session(sid) do |browser_manager|
          browser_manager.browser.at_css('#link-to-page2').click
          sleep 0.5
          browser_manager.browser.at_css('#link-to-page3').click
          sleep 0.5
        end

        # Go back twice: page3 -> page2 -> page1
        execute_tool_in_session(FerrumMCP::Tools::GoBackTool, sid, { session_id: sid })
        execute_tool_in_session(FerrumMCP::Tools::GoBackTool, sid, { session_id: sid })

        session_manager.with_session(sid) do |browser_manager|
          expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('1')
        end

        # Go forward to page 2
        execute_tool_in_session(described_class, sid, { session_id: sid })
        session_manager.with_session(sid) do |browser_manager|
          expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('2')
        end

        # Go forward to page 3
        execute_tool_in_session(described_class, sid, { session_id: sid })
        session_manager.with_session(sid) do |browser_manager|
          expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('3')
        end
      end

      it 'handles when there is no forward history' do
        sid = setup_session_with_fixture(session_manager, 'page1.html', subdir: 'navigation')

        # Try to go forward when there's no forward history
        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid }
        )

        # Should still succeed but stay on same page
        expect(result[:success]).to be true
      end
    end
  end

  describe FerrumMCP::Tools::RefreshTool do
    describe '.tool_name' do
      it 'returns refresh' do
        expect(described_class.tool_name).to eq('refresh')
      end
    end

    describe '#execute' do
      it 'refreshes the current page' do
        sid = setup_session_with_fixture(session_manager, 'page3.html', subdir: 'navigation')

        # Modify page content via JavaScript
        session_manager.with_session(sid) do |browser_manager|
          browser_manager.browser.execute('document.getElementById("page-title").textContent = "Modified Title";')
          expect(browser_manager.browser.at_css('#page-title').text).to eq('Modified Title')
        end

        # Refresh the page
        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid }
        )

        expect(result[:success]).to be true
        expect(result[:data][:url]).to include('/fixtures/navigation/page3')

        # Verify the page was refreshed (title reverted to original)
        session_manager.with_session(sid) do |browser_manager|
          expect(browser_manager.browser.at_css('#page-title').text).to eq('Navigation Test Page 3')
        end
      end

      it 'maintains navigation to the same URL after refresh' do
        sid = setup_session_with_fixture(session_manager, 'page2.html', subdir: 'navigation')

        original_url = session_manager.with_session(sid) do |browser_manager|
          browser_manager.browser.current_url
        end

        # Refresh
        execute_tool_in_session(described_class, sid, { session_id: sid })

        # Verify still on same URL
        session_manager.with_session(sid) do |browser_manager|
          expect(browser_manager.browser.current_url).to eq(original_url)
          expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('2')
        end
      end

      it 'clears dynamic DOM modifications on refresh' do
        sid = setup_session_with_fixture(session_manager, 'page1.html', subdir: 'navigation')

        # Add dynamic content
        session_manager.with_session(sid) do |browser_manager|
          browser_manager.browser.execute(<<~JS)
            var div = document.createElement('div');
            div.id = 'dynamic-element';
            div.textContent = 'Dynamic Content';
            document.body.appendChild(div);
          JS
          expect(browser_manager.browser.at_css('#dynamic-element')).not_to be_nil
        end

        # Refresh
        execute_tool_in_session(described_class, sid, { session_id: sid })

        # Verify dynamic content is gone (css returns empty array for missing elements)
        session_manager.with_session(sid) do |browser_manager|
          element = browser_manager.browser.css('#dynamic-element').first
          expect(element).to be_nil
        end
      end
    end
  end

  describe 'navigation integration scenarios' do
    # rubocop:disable RSpec/MultipleExpectations
    it 'handles complex navigation flow' do
      sid = setup_session_with_fixture(session_manager, 'page1.html', subdir: 'navigation')

      # Navigate: page1 -> page2 -> page3
      session_manager.with_session(sid) do |browser_manager|
        browser_manager.browser.at_css('#link-to-page2').click
        sleep 0.5
        browser_manager.browser.at_css('#link-to-page3').click
        sleep 0.5
        expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('3')
      end

      # Back to page 2
      execute_tool_in_session(FerrumMCP::Tools::GoBackTool, sid, { session_id: sid })
      session_manager.with_session(sid) do |browser_manager|
        expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('2')
      end

      # Refresh page 2
      execute_tool_in_session(FerrumMCP::Tools::RefreshTool, sid, { session_id: sid })
      session_manager.with_session(sid) do |browser_manager|
        expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('2')
      end

      # Forward to page 3
      execute_tool_in_session(FerrumMCP::Tools::GoForwardTool, sid, { session_id: sid })
      session_manager.with_session(sid) do |browser_manager|
        expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('3')
      end

      # Navigate to new URL (page1)
      execute_tool_in_session(
        FerrumMCP::Tools::NavigateTool,
        sid,
        { session_id: sid, url: test_url('/fixtures/navigation/page1') }
      )

      session_manager.with_session(sid) do |browser_manager|
        expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('1')
      end

      # Verify can't go forward (new navigation clears forward history)
      execute_tool_in_session(FerrumMCP::Tools::GoForwardTool, sid, { session_id: sid })
      session_manager.with_session(sid) do |browser_manager|
        expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('1')
      end
    end
    # rubocop:enable RSpec/MultipleExpectations

    it 'works correctly across multiple sessions' do
      sid1 = setup_session_with_fixture(session_manager, 'page1.html', subdir: 'navigation')
      sid2 = setup_session_with_fixture(session_manager, 'page2.html', subdir: 'navigation')

      # Verify both sessions are on different pages
      session_manager.with_session(sid1) do |browser_manager|
        expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('1')
      end

      session_manager.with_session(sid2) do |browser_manager|
        expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('2')
      end

      # Navigate session 1 to page 3
      execute_tool_in_session(
        FerrumMCP::Tools::NavigateTool,
        sid1,
        { session_id: sid1, url: test_url('/fixtures/navigation/page3') }
      )

      # Refresh session 2
      execute_tool_in_session(FerrumMCP::Tools::RefreshTool, sid2, { session_id: sid2 })

      # Verify sessions remain independent
      session_manager.with_session(sid1) do |browser_manager|
        expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('3')
      end

      session_manager.with_session(sid2) do |browser_manager|
        expect(browser_manager.browser.at_css('#page-marker').attribute('data-page')).to eq('2')
      end
    end
  end
end
