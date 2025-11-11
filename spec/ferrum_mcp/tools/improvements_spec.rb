# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Tool Improvements' do
  let(:config) { test_config }
  let(:browser_manager) { FerrumMCP::BrowserManager.new(config) }
  let(:navigate_tool) { FerrumMCP::Tools::NavigateTool.new(browser_manager) }

  before do
    browser_manager.start
  end

  after do
    browser_manager.stop
  end

  describe 'Press Key Improvements' do
    let(:press_key_tool) { FerrumMCP::Tools::PressKeyTool.new(browser_manager) }
    let(:fill_form_tool) { FerrumMCP::Tools::FillFormTool.new(browser_manager) }

    before do
      navigate_tool.execute({ url: test_url })
    end

    it 'presses Enter key without duplicating characters' do
      # Fill a form field
      fill_form_tool.execute({
                               fields: [
                                 { selector: '#search-input', value: 'test' }
                               ]
                             })

      # Press Enter
      result = press_key_tool.execute({ key: 'Enter', selector: '#search-input' })

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('Pressed key: Enter')

      # Verify the input still contains only 'test', not 'testE' or duplicate
      browser = browser_manager.browser
      value = browser.at_css('#search-input').property('value')
      expect(value).to eq('test')
    end

    it 'normalizes key names correctly' do
      test_keys = %w[enter tab escape backspace delete]

      test_keys.each do |key|
        result = press_key_tool.execute({ key: key })
        expect(result[:success]).to be true
      end
    end

    it 'handles arrow keys' do
      arrow_keys = %w[ArrowDown ArrowUp ArrowLeft ArrowRight down up left right]

      arrow_keys.each do |key|
        result = press_key_tool.execute({ key: key })
        expect(result[:success]).to be true
      end
    end
  end

  describe 'Click on Hidden Elements' do
    let(:click_tool) { FerrumMCP::Tools::ClickTool.new(browser_manager) }

    before do
      navigate_tool.execute({ url: test_url })
      # Create a hidden element
      browser_manager.browser.execute(<<~JAVASCRIPT)
        const hidden = document.createElement('button');
        hidden.id = 'hidden-button';
        hidden.style.display = 'none';
        hidden.textContent = 'Hidden';
        hidden.onclick = () => { window.hiddenClicked = true; };
        document.body.appendChild(hidden);
      JAVASCRIPT
    end

    it 'clicks on hidden element with force: true' do
      result = click_tool.execute({ selector: '#hidden-button', force: true })

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('forced')

      # Verify click worked
      clicked = browser_manager.browser.evaluate('window.hiddenClicked')
      expect(clicked).to be true
    end

    it 'fails to click hidden element without force' do
      result = click_tool.execute({ selector: '#hidden-button', force: false })

      expect(result[:success]).to be false
      expect(result[:error]).to include('Try with force: true')
    end
  end

  describe 'Drag and Drop' do
    let(:drag_tool) { FerrumMCP::Tools::DragAndDropTool.new(browser_manager) }

    before do
      navigate_tool.execute({ url: test_url })
      # Create draggable and droppable elements
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

    it 'drags element to target element' do
      result = drag_tool.execute({
                                   source_selector: '#draggable',
                                   target_selector: '#droppable',
                                   steps: 20
                                 })

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('Dragged from')
    end

    it 'drags element to coordinates' do
      result = drag_tool.execute({
                                   source_selector: '#draggable',
                                   target_x: 400,
                                   target_y: 400,
                                   steps: 15
                                 })

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('400')
    end

    it 'fails without target' do
      result = drag_tool.execute({
                                   source_selector: '#draggable'
                                 })

      expect(result[:success]).to be false
      expect(result[:error]).to include('target_selector or both target_x and target_y must be provided')
    end
  end

  describe 'XPath Support in get_text' do
    let(:get_text_tool) { FerrumMCP::Tools::GetTextTool.new(browser_manager) }

    before do
      navigate_tool.execute({ url: test_url })
      # Create test elements
      browser_manager.browser.execute(<<~JAVASCRIPT)
        const div = document.createElement('div');
        div.className = 'test-class';
        div.textContent = 'Test Content';
        document.body.appendChild(div);

        const span = document.createElement('span');
        span.id = 'test-span';
        span.textContent = 'Span Content';
        document.body.appendChild(span);
      JAVASCRIPT
    end

    it 'extracts text using XPath with xpath: prefix' do
      result = get_text_tool.execute({ selector: 'xpath://div[@class="test-class"]' })

      expect(result[:success]).to be true
      expect(result[:data][:text]).to include('Test Content')
    end

    it 'extracts text using XPath without prefix' do
      result = get_text_tool.execute({ selector: '//span[@id="test-span"]' })

      expect(result[:success]).to be true
      expect(result[:data][:text]).to include('Span Content')
    end

    it 'extracts multiple texts using XPath' do
      # Add more elements
      browser_manager.browser.execute(<<~JAVASCRIPT)
        ['One', 'Two', 'Three'].forEach(text => {
          const p = document.createElement('p');
          p.className = 'xpath-test';
          p.textContent = text;
          document.body.appendChild(p);
        });
      JAVASCRIPT

      result = get_text_tool.execute({ selector: '//p[@class="xpath-test"]', multiple: true })

      expect(result[:success]).to be true
      expect(result[:data][:texts]).to include('One', 'Two', 'Three')
      expect(result[:data][:count]).to eq(3)
    end
  end

  describe 'Shadow DOM Support' do
    let(:shadow_tool) { FerrumMCP::Tools::QueryShadowDOMTool.new(browser_manager) }

    before do
      navigate_tool.execute({ url: test_url })
      # Create Shadow DOM
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

    it 'clicks element in Shadow DOM' do
      result = shadow_tool.execute({
                                     host_selector: '#shadow-host',
                                     shadow_selector: '#shadow-button',
                                     action: 'click'
                                   })

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('Clicked element in Shadow DOM')

      # Verify click
      clicked = browser_manager.browser.evaluate('window.shadowButtonClicked')
      expect(clicked).to be true
    end

    it 'extracts text from Shadow DOM' do
      result = shadow_tool.execute({
                                     host_selector: '#shadow-host',
                                     shadow_selector: '#shadow-span',
                                     action: 'get_text'
                                   })

      expect(result[:success]).to be true
      expect(result[:data][:text]).to eq('Shadow Span')
    end

    it 'extracts HTML from Shadow DOM' do
      result = shadow_tool.execute({
                                     host_selector: '#shadow-host',
                                     shadow_selector: '#shadow-button',
                                     action: 'get_html'
                                   })

      expect(result[:success]).to be true
      expect(result[:data][:html]).to eq('Shadow Button')
    end

    it 'gets attribute from Shadow DOM' do
      result = shadow_tool.execute({
                                     host_selector: '#shadow-host',
                                     shadow_selector: '#shadow-button',
                                     action: 'get_attribute',
                                     attribute: 'data-test'
                                   })

      expect(result[:success]).to be true
      expect(result[:data][:value]).to eq('value')
    end

    it 'fails when Shadow DOM host not found' do
      result = shadow_tool.execute({
                                     host_selector: '#non-existent',
                                     shadow_selector: '#shadow-button',
                                     action: 'click'
                                   })

      expect(result[:success]).to be false
      expect(result[:error]).to include('Shadow DOM host not found')
    end

    it 'requires attribute parameter for get_attribute action' do
      result = shadow_tool.execute({
                                     host_selector: '#shadow-host',
                                     shadow_selector: '#shadow-button',
                                     action: 'get_attribute'
                                   })

      expect(result[:success]).to be false
      expect(result[:error]).to include('attribute parameter required')
    end
  end
end
