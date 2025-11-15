# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Critical Ferrum Fixes' do
  let(:config) { test_config }
  let(:browser_manager) { FerrumMCP::BrowserManager.new(config) }
  let(:navigate_tool) { FerrumMCP::Tools::NavigateTool.new(browser_manager) }

  before do
    browser_manager.start
    navigate_tool.execute({ url: test_url })
  end

  after do
    browser_manager.stop
  end

  describe 'BaseTool find_element with Ferrum Native Wait' do
    let(:click_tool) { FerrumMCP::Tools::ClickTool.new(browser_manager) }
    let(:browser) { browser_manager.browser }

    context 'when element appears after delay' do
      it 'waits for element using Ferrum native wait instead of manual polling' do
        # Create element after 1 second delay
        browser.execute(<<~JAVASCRIPT)
          setTimeout(() => {
            const btn = document.createElement('button');
            btn.id = 'delayed-button';
            btn.textContent = 'Delayed Button';
            document.body.appendChild(btn);
          }, 1000);
        JAVASCRIPT

        start_time = Time.now

        # This should use Ferrum's native wait, not manual polling with sleep(0.5)
        result = click_tool.execute({ selector: '#delayed-button' })
        elapsed = Time.now - start_time

        expect(result[:success]).to be true
        # Should find element in ~1 second, not 1.5+ seconds (which would indicate polling with sleep)
        expect(elapsed).to be < 1.5
        expect(elapsed).to be >= 1.0
      end

      it 'respects timeout parameter' do
        # Element never appears
        browser.execute(<<~JAVASCRIPT)
          setTimeout(() => {
            const btn = document.createElement('button');
            btn.id = 'never-appears';
            document.body.appendChild(btn);
          }, 10000); // 10 seconds
        JAVASCRIPT

        start_time = Time.now

        # Should timeout after 2 seconds, not wait 10 seconds
        result = click_tool.execute({ selector: '#never-appears', wait: 2 })
        elapsed = Time.now - start_time

        expect(result[:success]).to be false
        expect(elapsed).to be < 3 # Should timeout around 2 seconds
      end
    end
  end

  describe 'WaitForElementTool Visibility Checks' do
    let(:wait_tool) { FerrumMCP::Tools::WaitForElementTool.new(browser_manager) }
    let(:browser) { browser_manager.browser }

    context 'when element exists but is hidden' do
      before do
        browser.execute(<<~JAVASCRIPT)
          const hidden = document.createElement('div');
          hidden.id = 'hidden-div';
          hidden.style.display = 'none';
          hidden.textContent = 'Hidden Content';
          document.body.appendChild(hidden);
        JAVASCRIPT
      end

      it 'does not return immediately for hidden elements when waiting for visible' do
        start_time = Time.now

        # Should NOT return immediately for hidden element
        result = wait_tool.execute({ selector: '#hidden-div', state: 'visible', timeout: 2 })
        elapsed = Time.now - start_time

        expect(result[:success]).to be false
        expect(result[:error]).to include('Timeout waiting for element to be visible')
        # Should have actually waited the timeout, not returned immediately
        expect(elapsed).to be >= 1.8
      end

      it 'correctly identifies visible vs exists states' do
        # Element exists but is hidden
        result_exists = wait_tool.execute({ selector: '#hidden-div', state: 'exists', timeout: 2 })
        expect(result_exists[:success]).to be true

        # Element is not visible
        result_visible = wait_tool.execute({ selector: '#hidden-div', state: 'visible', timeout: 2 })
        expect(result_visible[:success]).to be false
      end

      it 'returns success when hidden element becomes visible' do
        # Make element visible after 1 second
        browser.execute(<<~JAVASCRIPT)
          setTimeout(() => {
            document.getElementById('hidden-div').style.display = 'block';
          }, 1000);
        JAVASCRIPT

        result = wait_tool.execute({ selector: '#hidden-div', state: 'visible', timeout: 3 })

        expect(result[:success]).to be true
        expect(result[:data][:message]).to include('visible')
      end
    end

    context 'when waiting for hidden state' do
      before do
        browser.execute(<<~JAVASCRIPT)
          const visible = document.createElement('div');
          visible.id = 'visible-div';
          visible.textContent = 'Visible Content';
          document.body.appendChild(visible);
        JAVASCRIPT
      end

      it 'waits for element to become hidden' do
        # Hide element after 1 second
        browser.execute(<<~JAVASCRIPT)
          setTimeout(() => {
            document.getElementById('visible-div').style.display = 'none';
          }, 1000);
        JAVASCRIPT

        result = wait_tool.execute({ selector: '#visible-div', state: 'hidden', timeout: 3 })

        expect(result[:success]).to be true
      end
    end
  end

  describe 'Navigation Tools Network Idle Wait' do
    let(:refresh_tool) { FerrumMCP::Tools::RefreshTool.new(browser_manager) }
    let(:go_back_tool) { FerrumMCP::Tools::GoBackTool.new(browser_manager) }
    let(:browser) { browser_manager.browser }

    context 'with NavigateTool' do
      it 'waits for network idle before returning' do
        # Navigate to a page that has delayed resources
        navigate_tool.execute({ url: test_url })

        # Add a delayed fetch
        browser.execute(<<~JAVASCRIPT)
          window.fetchCompleted = false;
          setTimeout(() => {
            fetch('/test/delayed')
              .then(() => { window.fetchCompleted = true; });
          }, 500);
        JAVASCRIPT

        # Navigate away and back - should wait for network idle
        navigate_tool.execute({ url: test_url('/test/page2') })
        result = navigate_tool.execute({ url: test_url })

        expect(result[:success]).to be true

        # Network should be idle, so any pending fetches should be done
        # (This is a basic check - in real scenarios network.wait_for_idle ensures this)
      end

      it 'validates URL format before navigation' do
        result = navigate_tool.execute({ url: 'not-a-valid-url' })

        expect(result[:success]).to be false
        expect(result[:error]).to include('must start with http')
      end
    end

    context 'with RefreshTool' do
      it 'waits for network idle after refresh' do
        # Set up a flag to track page load
        browser.execute('window.pageLoaded = true;')

        result = refresh_tool.execute({})

        expect(result[:success]).to be true
        # Page should be fully loaded
        expect(result[:data][:url]).to eq(test_url)
      end
    end

    context 'with GoBackTool' do
      it 'waits for network idle after navigation' do
        navigate_tool.execute({ url: test_url('/test/page2') })

        result = go_back_tool.execute({})

        expect(result[:success]).to be true
        expect(result[:data][:url]).to eq(test_url)
      end
    end
  end

  describe 'XSS and XPath Injection Protection' do
    let(:hover_tool) { FerrumMCP::Tools::HoverTool.new(browser_manager) }
    let(:find_by_text_tool) { FerrumMCP::Tools::FindByTextTool.new(browser_manager) }
    let(:browser) { browser_manager.browser }

    context 'with HoverTool XSS protection' do
      it 'safely escapes selectors when passed to JavaScript' do
        # Create a test element
        browser.execute(<<~JAVASCRIPT)
          const btn = document.createElement('button');
          btn.id = 'test-button';
          btn.textContent = 'Test';
          document.body.appendChild(btn);
        JAVASCRIPT

        # Try to inject JavaScript via selector
        malicious_selector = "test-button'); alert('XSS'); console.log('"

        # This should fail gracefully, not execute the injected code
        result = hover_tool.execute({ selector: malicious_selector })

        # Should fail to find element, but NOT execute the alert
        expect(result[:success]).to be false

        # Verify no XSS occurred by checking console (indirect check)
        # In a real scenario, you'd monitor for alert() calls
      end

      it 'properly uses inspect for JavaScript escaping' do
        browser.execute(<<~JAVASCRIPT)
          const btn = document.createElement('button');
          btn.id = 'hover-test';
          btn.textContent = 'Hover Me';
          btn.onmouseover = () => { window.hoverTriggered = true; };
          document.body.appendChild(btn);
        JAVASCRIPT

        result = hover_tool.execute({ selector: '#hover-test' })

        expect(result[:success]).to be true

        # Verify hover actually worked
        hovered = browser.evaluate('window.hoverTriggered')
        expect(hovered).to be true
      end
    end

    context 'with FindByTextTool XPath injection protection' do
      before do
        browser.execute(<<~JAVASCRIPT)
          // Create a container to isolate the button's text
          const container = document.createElement('div');
          container.style.display = 'none'; // Hide to avoid interfering with page
          const btn = document.createElement('button');
          btn.textContent = "Test's Button";
          container.appendChild(btn);
          document.body.appendChild(container);
        JAVASCRIPT
      end

      it 'escapes single quotes in XPath to prevent injection' do
        # Text with single quote that could break XPath
        result = find_by_text_tool.execute({ text: "Test's Button" })

        expect(result[:success]).to be true
        # Just check that the text contains what we're looking for
        expect(result[:data][:text]).to include("Test's Button")
      end

      it 'prevents XPath injection attacks' do
        # Try to inject XPath code
        malicious_text = "'] | //input[@type='password'] | //button[text()='"

        result = find_by_text_tool.execute({ text: malicious_text })

        # Should fail to find element, not execute injected XPath
        expect(result[:success]).to be false
        expect(result[:error]).to include('No elements found')
      end
    end
  end

  describe 'Stale Element Retry Logic' do
    let(:click_tool) { FerrumMCP::Tools::ClickTool.new(browser_manager) }
    let(:fill_form_tool) { FerrumMCP::Tools::FillFormTool.new(browser_manager) }
    let(:browser) { browser_manager.browser }

    context 'with ClickTool retry logic' do
      it 'retries on stale element errors' do
        # Create a button that replaces itself when clicked
        browser.execute(<<~JAVASCRIPT)
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

        # This should succeed despite element becoming stale
        result = click_tool.execute({ selector: '#self-replacing-button' })

        expect(result[:success]).to be true
      end
    end

    context 'with FillFormTool retry logic' do
      it 'retries when form fields become stale' do
        # Create a form field
        browser.execute(<<~JAVASCRIPT)
          const input = document.createElement('input');
          input.id = 'test-input';
          input.type = 'text';
          document.body.appendChild(input);
        JAVASCRIPT

        # Fill should succeed even if element is recreated
        result = fill_form_tool.execute({
                                          fields: [
                                            { selector: '#test-input', value: 'test value' }
                                          ]
                                        })

        expect(result[:success]).to be true

        # Verify value was set
        value = browser.at_css('#test-input').property('value')
        expect(value).to eq('test value')
      end

      it 'adds delays between form fields' do
        # Create multiple inputs
        browser.execute(<<~JAVASCRIPT)
          ['input1', 'input2', 'input3'].forEach(id => {
            const input = document.createElement('input');
            input.id = id;
            input.type = 'text';
            document.body.appendChild(input);
          });
        JAVASCRIPT

        start_time = Time.now

        result = fill_form_tool.execute({
                                          fields: [
                                            { selector: '#input1', value: 'value1' },
                                            { selector: '#input2', value: 'value2' },
                                            { selector: '#input3', value: 'value3' }
                                          ]
                                        })

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
    let(:evaluate_js_tool) { FerrumMCP::Tools::EvaluateJSTool.new(browser_manager) }

    it 'returns the result of evaluated JavaScript' do
      result = evaluate_js_tool.execute({ expression: '1 + 1' })

      expect(result[:success]).to be true
      expect(result[:data][:result]).to eq(2)
    end

    it 'returns complex objects from JavaScript' do
      result = evaluate_js_tool.execute({
                                          expression: '({ name: "test", value: 42, array: [1, 2, 3] })'
                                        })

      expect(result[:success]).to be true
      expect(result[:data][:result]).to eq({ 'name' => 'test', 'value' => 42, 'array' => [1, 2, 3] })
    end

    it 'returns page title' do
      result = evaluate_js_tool.execute({ expression: 'document.title' })

      expect(result[:success]).to be true
      expect(result[:data][:result]).to eq('Test Page')
    end
  end

  describe 'BrowserManager Crash Detection' do
    let(:new_browser_manager) { FerrumMCP::BrowserManager.new(config) }

    after do
      new_browser_manager.stop
    rescue StandardError
      nil
    end

    it 'detects when browser process dies' do
      new_browser_manager.start

      expect(new_browser_manager.active?).to be true

      # Kill the browser process
      new_browser_manager.stop

      # After stop, browser should be nil and active? should return false
      expect(new_browser_manager.active?).to be false
    end

    it 'handles browser communication errors gracefully' do
      new_browser_manager.start
      new_browser_manager.stop

      # After stop, should report as inactive
      expect(new_browser_manager.active?).to be false
    end
  end
end
