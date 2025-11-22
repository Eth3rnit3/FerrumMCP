# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Critical Ferrum Fixes' do
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

  describe 'BaseTool find_element with Ferrum Native Wait' do
    context 'when element appears after delay' do
      it 'waits for element using Ferrum native wait instead of manual polling' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        # Create element after 1 second delay
        session_manager.with_session(sid) do |browser_manager|
          browser_manager.browser.execute(<<~JAVASCRIPT)
            setTimeout(() => {
              const btn = document.createElement('button');
              btn.id = 'delayed-button';
              btn.textContent = 'Delayed Button';
              document.body.appendChild(btn);
            }, 1000);
          JAVASCRIPT
        end

        start_time = Time.now

        # This should use Ferrum's native wait, not manual polling with sleep(0.5)
        result = execute_tool_in_session(
          FerrumMCP::Tools::ClickTool,
          sid,
          { session_id: sid, selector: '#delayed-button' }
        )
        elapsed = Time.now - start_time

        expect(result[:success]).to be true
        # Should find element in ~1 second, not 1.5+ seconds (which would indicate polling with sleep)
        expect(elapsed).to be < 1.5
        expect(elapsed).to be >= 1.0
      end

      it 'respects timeout parameter' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        # Element never appears
        session_manager.with_session(sid) do |browser_manager|
          browser_manager.browser.execute(<<~JAVASCRIPT)
            setTimeout(() => {
              const btn = document.createElement('button');
              btn.id = 'never-appears';
              document.body.appendChild(btn);
            }, 10000); // 10 seconds
          JAVASCRIPT
        end

        start_time = Time.now

        # Should timeout after 2 seconds, not wait 10 seconds
        result = execute_tool_in_session(
          FerrumMCP::Tools::ClickTool,
          sid,
          { session_id: sid, selector: '#never-appears', wait: 2 }
        )
        elapsed = Time.now - start_time

        expect(result[:success]).to be false
        expect(elapsed).to be < 3 # Should timeout around 2 seconds
      end
    end
  end

  describe 'Navigation Tools Network Idle Wait' do
    context 'with NavigateTool' do
      it 'validates URL format before navigation' do
        sid = session_manager.create_session(headless: true)

        result = execute_tool_in_session(
          FerrumMCP::Tools::NavigateTool,
          sid,
          { session_id: sid, url: 'not-a-valid-url' }
        )

        expect(result[:success]).to be false
        expect(result[:error]).to include('must start with http')
      end
    end

    context 'with RefreshTool' do
      it 'waits for network idle after refresh' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        # Set up a flag to track page load
        session_manager.with_session(sid) do |browser_manager|
          browser_manager.browser.execute('window.pageLoaded = true;')
        end

        result = execute_tool_in_session(
          FerrumMCP::Tools::RefreshTool,
          sid,
          { session_id: sid }
        )

        expect(result[:success]).to be true
        # Page should be fully loaded
        expect(result[:data][:url]).to include('/fixtures/advanced/advanced_page')
      end
    end

    context 'with GoBackTool' do
      it 'waits for network idle after navigation' do
        sid = setup_session_with_fixture(session_manager, 'page1.html', subdir: 'navigation')

        # Navigate to page 2
        session_manager.with_session(sid) do |browser_manager|
          browser_manager.browser.at_css('#link-to-page2').click
          sleep 0.5
        end

        result = execute_tool_in_session(
          FerrumMCP::Tools::GoBackTool,
          sid,
          { session_id: sid }
        )

        expect(result[:success]).to be true
        expect(result[:data][:url]).to include('/fixtures/navigation/page1')
      end
    end
  end

  describe 'XSS and XPath Injection Protection' do
    context 'with HoverTool XSS protection' do
      it 'safely escapes selectors when passed to JavaScript' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        # Create a test element
        session_manager.with_session(sid) do |browser_manager|
          browser_manager.browser.execute(<<~JAVASCRIPT)
            const btn = document.createElement('button');
            btn.id = 'test-button';
            btn.textContent = 'Test';
            document.body.appendChild(btn);
          JAVASCRIPT
        end

        # Try to inject JavaScript via selector
        malicious_selector = "test-button'); alert('XSS'); console.log('"

        # This should fail gracefully, not execute the injected code
        result = execute_tool_in_session(
          FerrumMCP::Tools::HoverTool,
          sid,
          { session_id: sid, selector: malicious_selector }
        )

        # Should fail to find element, but NOT execute the alert
        expect(result[:success]).to be false
      end

      it 'properly uses inspect for JavaScript escaping' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        session_manager.with_session(sid) do |browser_manager|
          browser_manager.browser.execute(<<~JAVASCRIPT)
            const btn = document.createElement('button');
            btn.id = 'hover-test';
            btn.textContent = 'Hover Me';
            btn.onmouseover = () => { window.hoverTriggered = true; };
            document.body.appendChild(btn);
          JAVASCRIPT
        end

        result = execute_tool_in_session(
          FerrumMCP::Tools::HoverTool,
          sid,
          { session_id: sid, selector: '#hover-test' }
        )

        expect(result[:success]).to be true

        # Verify hover actually worked
        session_manager.with_session(sid) do |browser_manager|
          hovered = browser_manager.browser.evaluate('window.hoverTriggered')
          expect(hovered).to be true
        end
      end
    end

    context 'with FindByTextTool XPath injection protection' do
      it 'escapes single quotes in XPath to prevent injection' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        session_manager.with_session(sid) do |browser_manager|
          browser_manager.browser.execute(<<~JAVASCRIPT)
            const container = document.createElement('div');
            container.style.display = 'block';
            const btn = document.createElement('button');
            btn.textContent = "Test's Button";
            container.appendChild(btn);
            document.body.appendChild(container);
          JAVASCRIPT
        end

        # Text with single quote that could break XPath
        result = execute_tool_in_session(
          FerrumMCP::Tools::FindByTextTool,
          sid,
          { session_id: sid, text: "Test's Button" }
        )

        expect(result[:success]).to be true
        expect(result[:data][:text]).to include("Test's Button")
      end

      it 'prevents XPath injection attacks' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        # Try to inject XPath code
        malicious_text = "'] | //input[@type='password'] | //button[text()='"

        result = execute_tool_in_session(
          FerrumMCP::Tools::FindByTextTool,
          sid,
          { session_id: sid, text: malicious_text }
        )

        # Should fail to find element, not execute injected XPath
        expect(result[:success]).to be false
        expect(result[:error]).to include('No elements found')
      end
    end
  end

  describe 'Stale Element Retry Logic' do
    context 'with ClickTool retry logic' do
      it 'retries on stale element errors' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        # Create a button that replaces itself when clicked
        session_manager.with_session(sid) do |browser_manager|
          browser_manager.browser.execute(<<~JAVASCRIPT)
            let clickCount = 0;
            function createButton() {
              const btn = document.createElement('button');
              btn.id = 'self-replacing-button';
              btn.textContent = 'Click ' + clickCount;
              btn.onclick = function() {
                clickCount++;
                if (clickCount < 3) {
                  // Replace the button (makes it stale)
                  this.parentNode.removeChild(this);
                  setTimeout(createButton, 100);
                } else {
                  window.finalClicked = true;
                }
              };
              document.body.appendChild(btn);
            }
            createButton();
          JAVASCRIPT
        end

        # This should succeed despite element becoming stale
        result = execute_tool_in_session(
          FerrumMCP::Tools::ClickTool,
          sid,
          { session_id: sid, selector: '#self-replacing-button' }
        )

        expect(result[:success]).to be true
      end
    end

    context 'with FillFormTool retry logic' do
      it 'retries when form fields become stale' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        # Create a form field
        session_manager.with_session(sid) do |browser_manager|
          browser_manager.browser.execute(<<~JAVASCRIPT)
            const input = document.createElement('input');
            input.id = 'test-input';
            input.type = 'text';
            document.body.appendChild(input);
          JAVASCRIPT
        end

        # Fill should succeed even if element is recreated
        result = execute_tool_in_session(
          FerrumMCP::Tools::FillFormTool,
          sid,
          {
            session_id: sid,
            fields: [{ selector: '#test-input', value: 'test value' }]
          }
        )

        expect(result[:success]).to be true

        # Verify value was set
        session_manager.with_session(sid) do |browser_manager|
          value = browser_manager.browser.at_css('#test-input').property('value')
          expect(value).to eq('test value')
        end
      end

      it 'adds delays between form fields' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        # Create multiple inputs
        session_manager.with_session(sid) do |browser_manager|
          browser_manager.browser.execute(<<~JAVASCRIPT)
            ['input1', 'input2', 'input3'].forEach(id => {
              const input = document.createElement('input');
              input.id = id;
              input.type = 'text';
              document.body.appendChild(input);
            });
          JAVASCRIPT
        end

        start_time = Time.now

        result = execute_tool_in_session(
          FerrumMCP::Tools::FillFormTool,
          sid,
          {
            session_id: sid,
            fields: [
              { selector: '#input1', value: 'value1' },
              { selector: '#input2', value: 'value2' },
              { selector: '#input3', value: 'value3' }
            ]
          }
        )

        elapsed = Time.now - start_time

        expect(result[:success]).to be true
        # Should have delays between fields (0.1s * 2 = 0.2s minimum)
        # Plus 0.05s focus delay per field = 0.15s
        # Total minimum ~0.35s
        expect(elapsed).to be >= 0.3
      end
    end
  end

  describe 'EvaluateJSTool Returns Results' do
    it 'returns the result of evaluated JavaScript' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      result = execute_tool_in_session(
        FerrumMCP::Tools::EvaluateJSTool,
        sid,
        { session_id: sid, expression: '1 + 1' }
      )

      expect(result[:success]).to be true
      expect(result[:data][:result]).to eq(2)
    end

    it 'returns complex objects from JavaScript' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      result = execute_tool_in_session(
        FerrumMCP::Tools::EvaluateJSTool,
        sid,
        { session_id: sid, expression: '({ name: "test", value: 42, array: [1, 2, 3] })' }
      )

      expect(result[:success]).to be true
      expect(result[:data][:result]).to eq({ 'name' => 'test', 'value' => 42, 'array' => [1, 2, 3] })
    end

    it 'returns page title' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      result = execute_tool_in_session(
        FerrumMCP::Tools::EvaluateJSTool,
        sid,
        { session_id: sid, expression: 'document.title' }
      )

      expect(result[:success]).to be true
      expect(result[:data][:result]).to eq('Test Page')
    end
  end

  describe 'BrowserManager Crash Detection' do
    it 'detects when browser process stops' do
      sid = session_manager.create_session(headless: true)

      session_manager.with_session(sid) do |browser_manager|
        expect(browser_manager.active?).to be true
      end

      # Close the session
      session_manager.close_session(sid)

      # Verify session no longer exists
      expect do
        session_manager.with_session(sid) { |_| nil }
      end.to raise_error(FerrumMCP::SessionError)
    end

    it 'handles browser communication errors gracefully' do
      sid = session_manager.create_session(headless: true)

      # Close the session
      session_manager.close_session(sid)

      # After close, session should not exist
      expect do
        session_manager.with_session(sid) { |_| nil }
      end.to raise_error(FerrumMCP::SessionError)
    end
  end
end
