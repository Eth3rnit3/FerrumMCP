# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Navigation Tools' do
  let(:config) { test_config }
  let(:browser_manager) { FerrumMCP::BrowserManager.new(config) }
  let(:navigate_tool) { FerrumMCP::Tools::NavigateTool.new(browser_manager) }
  let(:go_back_tool) { FerrumMCP::Tools::GoBackTool.new(browser_manager) }
  let(:go_forward_tool) { FerrumMCP::Tools::GoForwardTool.new(browser_manager) }
  let(:refresh_tool) { FerrumMCP::Tools::RefreshTool.new(browser_manager) }

  before do
    browser_manager.start
  end

  after do
    browser_manager.stop
  end

  describe FerrumMCP::Tools::NavigateTool do
    it 'navigates to a URL' do
      result = navigate_tool.execute({ url: test_url })

      expect(result[:success]).to be true
      expect(result[:data][:url]).to eq(test_url)
      expect(result[:data][:title]).to eq('Test Page')
    end

    it 'returns error for invalid URL' do
      result = navigate_tool.execute({ url: 'not-a-valid-url' })

      expect(result[:success]).to be false
      expect(result[:error]).to include('Failed to navigate')
    end
  end

  describe FerrumMCP::Tools::GoBackTool do
    it 'goes back to previous page' do
      navigate_tool.execute({ url: test_url })
      navigate_tool.execute({ url: test_url('/test/page2') })

      result = go_back_tool.execute({})

      expect(result[:success]).to be true
      expect(result[:data][:url]).to eq(test_url)
    end
  end

  describe FerrumMCP::Tools::GoForwardTool do
    it 'goes forward after going back' do
      navigate_tool.execute({ url: test_url })
      navigate_tool.execute({ url: test_url('/test/page2') })
      go_back_tool.execute({})

      result = go_forward_tool.execute({})

      expect(result[:success]).to be true
      expect(result[:data][:url]).to eq(test_url('/test/page2'))
    end
  end

  describe FerrumMCP::Tools::RefreshTool do
    it 'refreshes the current page' do
      navigate_tool.execute({ url: test_url })

      result = refresh_tool.execute({})

      expect(result[:success]).to be true
      expect(result[:data][:url]).to eq(test_url)
    end
  end
end
