# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Tool Improvements' do
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

  describe 'Press Key Improvements' do
    it 'presses Enter key without duplicating characters' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      # Fill a form field
      execute_tool_in_session(
        FerrumMCP::Tools::FillFormTool,
        sid,
        {
          session_id: sid,
          fields: [{ selector: '#search-input', value: 'test' }]
        }
      )

      # Press Enter
      result = execute_tool_in_session(
        FerrumMCP::Tools::PressKeyTool,
        sid,
        { session_id: sid, key: 'Enter', selector: '#search-input' }
      )

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('Pressed key: Enter')

      # Verify the input still contains only 'test', not 'testE' or duplicate
      session_manager.with_session(sid) do |browser_manager|
        value = browser_manager.browser.at_css('#search-input').property('value')
        expect(value).to eq('test')
      end
    end

    it 'normalizes key names correctly' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      test_keys = %w[enter tab escape backspace delete]

      test_keys.each do |key|
        result = execute_tool_in_session(
          FerrumMCP::Tools::PressKeyTool,
          sid,
          { session_id: sid, key: key }
        )
        expect(result[:success]).to be true
      end
    end

    it 'handles arrow keys' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      arrow_keys = %w[ArrowDown ArrowUp ArrowLeft ArrowRight down up left right]

      arrow_keys.each do |key|
        result = execute_tool_in_session(
          FerrumMCP::Tools::PressKeyTool,
          sid,
          { session_id: sid, key: key }
        )
        expect(result[:success]).to be true
      end
    end
  end

  describe 'Click on Hidden Elements' do
    it 'clicks on hidden element with force: true' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      # Create a hidden element
      session_manager.with_session(sid) do |browser_manager|
        browser_manager.browser.execute(<<~JAVASCRIPT)
          const hidden = document.createElement('button');
          hidden.id = 'hidden-button';
          hidden.style.display = 'none';
          hidden.textContent = 'Hidden';
          hidden.onclick = () => { window.hiddenClicked = true; };
          document.body.appendChild(hidden);
        JAVASCRIPT
      end

      result = execute_tool_in_session(
        FerrumMCP::Tools::ClickTool,
        sid,
        { session_id: sid, selector: '#hidden-button', force: true }
      )

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('forced')

      # Verify click worked
      session_manager.with_session(sid) do |browser_manager|
        clicked = browser_manager.browser.evaluate('window.hiddenClicked')
        expect(clicked).to be true
      end
    end

    it 'fails to click hidden element without force' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      # Create a hidden element
      session_manager.with_session(sid) do |browser_manager|
        browser_manager.browser.execute(<<~JAVASCRIPT)
          const hidden = document.createElement('button');
          hidden.id = 'hidden-button';
          hidden.style.display = 'none';
          hidden.textContent = 'Hidden';
          document.body.appendChild(hidden);
        JAVASCRIPT
      end

      result = execute_tool_in_session(
        FerrumMCP::Tools::ClickTool,
        sid,
        { session_id: sid, selector: '#hidden-button', force: false }
      )

      expect(result[:success]).to be false
      expect(result[:error]).to include('Try with force: true')
    end
  end

  describe 'Drag and Drop' do
    it 'drags element to target element' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      # Create draggable and droppable elements
      session_manager.with_session(sid) do |browser_manager|
        browser_manager.browser.execute(<<~JAVASCRIPT)
          const draggable = document.createElement('div');
          draggable.id = 'draggable';
          draggable.style.cssText = 'width: 100px; height: 100px; background: blue; position: absolute; left: 50px; top: 50px;';
          draggable.draggable = true;

          const droppable = document.createElement('div');
          droppable.id = 'droppable';
          droppable.style.cssText = 'width: 200px; height: 200px; background: green; position: absolute; left: 300px; top: 300px;';

          window.dropSuccess = false;

          draggable.addEventListener('dragstart', (e) => {
            window.dragStarted = true;
          });

          droppable.addEventListener('drop', (e) => {
            e.preventDefault();
            window.dropSuccess = true;
          });

          droppable.addEventListener('dragover', (e) => {
            e.preventDefault();
          });

          document.body.appendChild(draggable);
          document.body.appendChild(droppable);
        JAVASCRIPT
      end

      result = execute_tool_in_session(
        FerrumMCP::Tools::DragAndDropTool,
        sid,
        {
          session_id: sid,
          source_selector: '#draggable',
          target_selector: '#droppable',
          steps: 20
        }
      )

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('Dragged from')
    end

    it 'drags element to coordinates' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      # Create draggable element
      session_manager.with_session(sid) do |browser_manager|
        browser_manager.browser.execute(<<~JAVASCRIPT)
          const draggable = document.createElement('div');
          draggable.id = 'draggable';
          draggable.style.cssText = 'width: 100px; height: 100px; background: blue; position: absolute; left: 50px; top: 50px;';
          draggable.draggable = true;
          document.body.appendChild(draggable);
        JAVASCRIPT
      end

      result = execute_tool_in_session(
        FerrumMCP::Tools::DragAndDropTool,
        sid,
        {
          session_id: sid,
          source_selector: '#draggable',
          target_x: 400,
          target_y: 400,
          steps: 15
        }
      )

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('400')
    end

    it 'fails without target' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      # Create draggable element
      session_manager.with_session(sid) do |browser_manager|
        browser_manager.browser.execute(<<~JAVASCRIPT)
          const draggable = document.createElement('div');
          draggable.id = 'draggable';
          draggable.draggable = true;
          document.body.appendChild(draggable);
        JAVASCRIPT
      end

      result = execute_tool_in_session(
        FerrumMCP::Tools::DragAndDropTool,
        sid,
        { session_id: sid, source_selector: '#draggable' }
      )

      expect(result[:success]).to be false
      expect(result[:error]).to include('target_selector or both target_x and target_y must be provided')
    end
  end

  describe 'XPath Support in get_text' do
    it 'extracts text using XPath with xpath: prefix' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      # Create test elements
      session_manager.with_session(sid) do |browser_manager|
        browser_manager.browser.execute(<<~JAVASCRIPT)
          const div = document.createElement('div');
          div.className = 'test-class';
          div.textContent = 'Test Content';
          document.body.appendChild(div);
        JAVASCRIPT
      end

      result = execute_tool_in_session(
        FerrumMCP::Tools::GetTextTool,
        sid,
        { session_id: sid, selector: 'xpath://div[@class="test-class"]' }
      )

      expect(result[:success]).to be true
      expect(result[:data][:text]).to include('Test Content')
    end

    it 'extracts text using XPath without prefix' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      # Create test elements
      session_manager.with_session(sid) do |browser_manager|
        browser_manager.browser.execute(<<~JAVASCRIPT)
          const span = document.createElement('span');
          span.id = 'test-span';
          span.textContent = 'Span Content';
          document.body.appendChild(span);
        JAVASCRIPT
      end

      result = execute_tool_in_session(
        FerrumMCP::Tools::GetTextTool,
        sid,
        { session_id: sid, selector: '//span[@id="test-span"]' }
      )

      expect(result[:success]).to be true
      expect(result[:data][:text]).to include('Span Content')
    end

    it 'extracts multiple texts using XPath' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      # Add more elements
      session_manager.with_session(sid) do |browser_manager|
        browser_manager.browser.execute(<<~JAVASCRIPT)
          ['One', 'Two', 'Three'].forEach(text => {
            const p = document.createElement('p');
            p.className = 'xpath-test';
            p.textContent = text;
            document.body.appendChild(p);
          });
        JAVASCRIPT
      end

      result = execute_tool_in_session(
        FerrumMCP::Tools::GetTextTool,
        sid,
        { session_id: sid, selector: '//p[@class="xpath-test"]', multiple: true }
      )

      expect(result[:success]).to be true
      expect(result[:data][:texts]).to include('One', 'Two', 'Three')
      expect(result[:data][:count]).to eq(3)
    end
  end

  describe 'Shadow DOM Support' do
    it 'clicks element in Shadow DOM' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      # Create Shadow DOM
      session_manager.with_session(sid) do |browser_manager|
        browser_manager.browser.execute(<<~JAVASCRIPT)
          const host = document.createElement('div');
          host.id = 'shadow-host';
          document.body.appendChild(host);

          const shadow = host.attachShadow({ mode: 'open' });
          shadow.innerHTML = `
            <style>button { padding: 10px; }</style>
            <button id="shadow-button" data-test="value">Shadow Button</button>
            <span id="shadow-span">Shadow Span</span>
          `;

          const button = shadow.querySelector('#shadow-button');
          button.addEventListener('click', () => {
            window.shadowButtonClicked = true;
          });
        JAVASCRIPT
      end

      result = execute_tool_in_session(
        FerrumMCP::Tools::QueryShadowDOMTool,
        sid,
        {
          session_id: sid,
          host_selector: '#shadow-host',
          shadow_selector: '#shadow-button',
          action: 'click'
        }
      )

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('Clicked element in Shadow DOM')

      # Verify click
      session_manager.with_session(sid) do |browser_manager|
        clicked = browser_manager.browser.evaluate('window.shadowButtonClicked')
        expect(clicked).to be true
      end
    end

    it 'extracts text from Shadow DOM' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      # Create Shadow DOM
      session_manager.with_session(sid) do |browser_manager|
        browser_manager.browser.execute(<<~JAVASCRIPT)
          const host = document.createElement('div');
          host.id = 'shadow-host';
          document.body.appendChild(host);

          const shadow = host.attachShadow({ mode: 'open' });
          shadow.innerHTML = '<span id="shadow-span">Shadow Span</span>';
        JAVASCRIPT
      end

      result = execute_tool_in_session(
        FerrumMCP::Tools::QueryShadowDOMTool,
        sid,
        {
          session_id: sid,
          host_selector: '#shadow-host',
          shadow_selector: '#shadow-span',
          action: 'get_text'
        }
      )

      expect(result[:success]).to be true
      expect(result[:data][:text]).to eq('Shadow Span')
    end

    it 'extracts HTML from Shadow DOM' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      # Create Shadow DOM
      session_manager.with_session(sid) do |browser_manager|
        browser_manager.browser.execute(<<~JAVASCRIPT)
          const host = document.createElement('div');
          host.id = 'shadow-host';
          document.body.appendChild(host);

          const shadow = host.attachShadow({ mode: 'open' });
          shadow.innerHTML = '<button id="shadow-button">Shadow Button</button>';
        JAVASCRIPT
      end

      result = execute_tool_in_session(
        FerrumMCP::Tools::QueryShadowDOMTool,
        sid,
        {
          session_id: sid,
          host_selector: '#shadow-host',
          shadow_selector: '#shadow-button',
          action: 'get_html'
        }
      )

      expect(result[:success]).to be true
      expect(result[:data][:html]).to eq('Shadow Button')
    end

    it 'gets attribute from Shadow DOM' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      # Create Shadow DOM
      session_manager.with_session(sid) do |browser_manager|
        browser_manager.browser.execute(<<~JAVASCRIPT)
          const host = document.createElement('div');
          host.id = 'shadow-host';
          document.body.appendChild(host);

          const shadow = host.attachShadow({ mode: 'open' });
          shadow.innerHTML = '<button id="shadow-button" data-test="value">Shadow Button</button>';
        JAVASCRIPT
      end

      result = execute_tool_in_session(
        FerrumMCP::Tools::QueryShadowDOMTool,
        sid,
        {
          session_id: sid,
          host_selector: '#shadow-host',
          shadow_selector: '#shadow-button',
          action: 'get_attribute',
          attribute: 'data-test'
        }
      )

      expect(result[:success]).to be true
      expect(result[:data][:value]).to eq('value')
    end

    it 'fails when Shadow DOM host not found' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      result = execute_tool_in_session(
        FerrumMCP::Tools::QueryShadowDOMTool,
        sid,
        {
          session_id: sid,
          host_selector: '#non-existent',
          shadow_selector: '#shadow-button',
          action: 'click'
        }
      )

      expect(result[:success]).to be false
      expect(result[:error]).to include('Shadow DOM host not found')
    end

    it 'requires attribute parameter for get_attribute action' do
      sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

      # Create Shadow DOM
      session_manager.with_session(sid) do |browser_manager|
        browser_manager.browser.execute(<<~JAVASCRIPT)
          const host = document.createElement('div');
          host.id = 'shadow-host';
          document.body.appendChild(host);
          const shadow = host.attachShadow({ mode: 'open' });
          shadow.innerHTML = '<button id="shadow-button">Shadow Button</button>';
        JAVASCRIPT
      end

      result = execute_tool_in_session(
        FerrumMCP::Tools::QueryShadowDOMTool,
        sid,
        {
          session_id: sid,
          host_selector: '#shadow-host',
          shadow_selector: '#shadow-button',
          action: 'get_attribute'
        }
      )

      expect(result[:success]).to be false
      expect(result[:error]).to include('attribute parameter required')
    end
  end
end
