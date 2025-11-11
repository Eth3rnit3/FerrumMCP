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

    it 'does not fail when element not found (uses JavaScript)' do
      # HoverTool uses JavaScript and doesn't validate element existence
      result = hover_tool.execute({ selector: '#non-existent' })

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('Hovered over')
    end
  end
end
