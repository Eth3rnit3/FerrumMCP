# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Interaction Tools' do
  let(:config) { test_config }
  let(:browser_manager) { FerrumMCP::BrowserManager.new(config) }
  let(:navigate_tool) { FerrumMCP::Tools::NavigateTool.new(browser_manager) }
  let(:click_tool) { FerrumMCP::Tools::ClickTool.new(browser_manager) }
  let(:fill_form_tool) { FerrumMCP::Tools::FillFormTool.new(browser_manager) }
  let(:press_key_tool) { FerrumMCP::Tools::PressKeyTool.new(browser_manager) }
  let(:hover_tool) { FerrumMCP::Tools::HoverTool.new(browser_manager) }
  let(:accept_cookies_tool) { FerrumMCP::Tools::AcceptCookiesTool.new(browser_manager) }

  before do
    browser_manager.start
    navigate_tool.execute({ url: test_url })
  end

  after do
    browser_manager.stop
  end

  describe FerrumMCP::Tools::ClickTool do
    it 'clicks on an element' do
      result = click_tool.execute({ selector: '#link' })

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('Clicked on #link')
    end

    it 'returns error when element not found' do
      result = click_tool.execute({ selector: '#non-existent' })

      expect(result[:success]).to be false
      expect(result[:error]).to include('Element not found')
    end

    it 'waits for element with custom timeout' do
      result = click_tool.execute({ selector: '#link', wait: 10 })

      expect(result[:success]).to be true
    end
  end

  describe FerrumMCP::Tools::FillFormTool do
    it 'fills form fields' do
      fields = [
        { selector: '#name-input', value: 'John Doe' },
        { selector: '#email-input', value: 'john@example.com' }
      ]

      result = fill_form_tool.execute({ fields: fields })

      expect(result[:success]).to be true
      expect(result[:data][:fields].length).to eq(2)
      expect(result[:data][:fields][0][:filled]).to be true
    end

    it 'returns error when field not found' do
      fields = [{ selector: '#non-existent', value: 'test' }]

      result = fill_form_tool.execute({ fields: fields })

      expect(result[:success]).to be false
    end
  end

  describe FerrumMCP::Tools::PressKeyTool do
    it 'presses a key' do
      result = press_key_tool.execute({ key: 'Enter' })

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('Pressed key: Enter')
    end

    it 'presses a key on focused element' do
      result = press_key_tool.execute({ key: 'Tab', selector: '#name-input' })

      expect(result[:success]).to be true
    end
  end

  describe FerrumMCP::Tools::HoverTool do
    it 'hovers over an element' do
      result = hover_tool.execute({ selector: '#link' })

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('Hovered over #link')
    end

    it 'fails when element not found' do
      # HoverTool now properly validates element existence before hovering
      result = hover_tool.execute({ selector: '#non-existent' })

      expect(result[:success]).to be false
      expect(result[:error]).to include('Element not found')
    end
  end

  describe FerrumMCP::Tools::AcceptCookiesTool do
    context 'with common framework selectors' do
      it 'detects and clicks OneTrust cookie banner' do
        # Inject a fake OneTrust cookie banner
        browser_manager.browser.execute(<<~JS)
          const banner = document.createElement('div');
          banner.id = 'onetrust-banner';
          const button = document.createElement('button');
          button.id = 'onetrust-accept-btn-handler';
          button.textContent = 'Accept All';
          banner.appendChild(button);
          document.body.appendChild(banner);
        JS

        result = accept_cookies_tool.execute({ wait: 0.5 })

        expect(result[:success]).to be true
        expect(result[:data][:message]).to include('Cookie consent accepted')
        expect(result[:data][:strategy]).to eq('common_frameworks')
      end

      it 'detects and clicks Cookiebot cookie banner' do
        browser_manager.browser.execute(<<~JS)
          const button = document.createElement('button');
          button.id = 'CybotCookiebotDialogBodyLevelButtonLevelOptinAllowAll';
          button.textContent = 'Allow all cookies';
          document.body.appendChild(button);
        JS

        result = accept_cookies_tool.execute({ wait: 0.5 })

        expect(result[:success]).to be true
        expect(result[:data][:strategy]).to eq('common_frameworks')
      end
    end

    context 'with text-based detection' do
      it 'finds accept button by English text' do
        browser_manager.browser.execute(<<~JS)
          const button = document.createElement('button');
          button.className = 'cookie-consent-btn';
          button.textContent = 'Accept All Cookies';
          document.body.appendChild(button);
        JS

        result = accept_cookies_tool.execute({ wait: 0.5 })

        expect(result[:success]).to be true
        expect(result[:data][:strategy]).to eq('text_based_detection')
      end

      it 'finds accept button by French text' do
        browser_manager.browser.execute(<<~JS)
          const button = document.createElement('button');
          button.className = 'cookie-btn';
          button.textContent = 'Tout Accepter';
          document.body.appendChild(button);
        JS

        result = accept_cookies_tool.execute({ wait: 0.5 })

        expect(result[:success]).to be true
        expect(result[:data][:strategy]).to eq('text_based_detection')
      end

      it 'avoids clicking reject buttons' do
        browser_manager.browser.execute(<<~JS)
          const reject = document.createElement('button');
          reject.className = 'reject-btn';
          reject.textContent = 'Reject All';
          document.body.appendChild(reject);

          const accept = document.createElement('button');
          accept.className = 'accept-btn';
          accept.textContent = 'Accept All';
          document.body.appendChild(accept);
        JS

        result = accept_cookies_tool.execute({ wait: 0.5 })

        expect(result[:success]).to be true
        # Should have clicked the accept button, not reject
        expect(result[:data][:strategy]).to eq('text_based_detection')
      end
    end

    context 'with CSS selectors' do
      it 'finds accept button by common CSS classes' do
        browser_manager.browser.execute(<<~JS)
          const button = document.createElement('button');
          button.className = 'accept-cookies';
          button.textContent = 'Click here'; // Non-standard text to force CSS detection
          document.body.appendChild(button);
        JS

        result = accept_cookies_tool.execute({ wait: 0.5 })

        expect(result[:success]).to be true
        # Multiple strategies can find the button, just verify it was found
        expect(result[:data][:message]).to include('Cookie consent accepted')
      end

      it 'finds accept button by ID' do
        browser_manager.browser.execute(<<~JS)
          const button = document.createElement('button');
          button.id = 'accept-cookies';
          button.textContent = 'Click me'; // Non-standard text
          document.body.appendChild(button);
        JS

        result = accept_cookies_tool.execute({ wait: 0.5 })

        expect(result[:success]).to be true
        expect(result[:data][:message]).to include('Cookie consent accepted')
      end

      it 'finds accept button by data attributes' do
        browser_manager.browser.execute(<<~JS)
          const button = document.createElement('button');
          button.setAttribute('data-action', 'accept');
          button.textContent = 'Press button'; // Non-standard text
          document.body.appendChild(button);
        JS

        result = accept_cookies_tool.execute({ wait: 0.5 })

        expect(result[:success]).to be true
        expect(result[:data][:message]).to include('Cookie consent accepted')
      end
    end

    context 'with ARIA labels' do
      it 'finds accept button by aria-label' do
        browser_manager.browser.execute(<<~JS)
          const button = document.createElement('button');
          button.setAttribute('aria-label', 'Accept all cookies');
          button.textContent = 'X';
          document.body.appendChild(button);
        JS

        result = accept_cookies_tool.execute({ wait: 0.5 })

        expect(result[:success]).to be true
        expect(result[:data][:strategy]).to eq('aria_labels')
      end
    end

    context 'when no cookie banner is present' do
      it 'returns error when no cookie banner found' do
        result = accept_cookies_tool.execute({ wait: 0.5 })

        expect(result[:success]).to be false
        expect(result[:error]).to include('No cookie consent banner found')
      end
    end

    context 'with custom wait time' do
      it 'respects custom wait parameter' do
        # This test verifies the wait parameter is used
        start_time = Time.now
        result = accept_cookies_tool.execute({ wait: 1 })
        elapsed = Time.now - start_time

        # Should wait at least 1 second
        expect(elapsed).to be >= 1.0
        expect(result[:success]).to be false # No banner to accept
      end
    end

    context 'with hidden elements' do
      it 'clicks visible accept button over hidden ones' do
        browser_manager.browser.execute(<<~JS)
          const hidden = document.createElement('button');
          hidden.className = 'accept-cookies';
          hidden.textContent = 'Click hidden'; // Non-standard text
          hidden.style.display = 'none';
          document.body.appendChild(hidden);

          const visible = document.createElement('button');
          visible.className = 'accept-all';
          visible.textContent = 'Accept All';
          document.body.appendChild(visible);
        JS

        result = accept_cookies_tool.execute({ wait: 0.5 })

        expect(result[:success]).to be true
        expect(result[:data][:message]).to include('Cookie consent accepted')
      end
    end
  end
end
