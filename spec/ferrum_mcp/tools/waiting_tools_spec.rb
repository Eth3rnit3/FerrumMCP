# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Waiting Tools' do
  let(:config) { test_config }
  let(:browser_manager) { FerrumMCP::BrowserManager.new(config) }
  let(:navigate_tool) { FerrumMCP::Tools::NavigateTool.new(browser_manager) }
  let(:wait_for_element_tool) { FerrumMCP::Tools::WaitForElementTool.new(browser_manager) }
  let(:wait_tool) { FerrumMCP::Tools::WaitTool.new(browser_manager) }

  before do
    browser_manager.start
    navigate_tool.execute({ url: test_url })
  end

  after do
    browser_manager.stop
  end

  describe FerrumMCP::Tools::WaitForElementTool do
    it 'waits for visible element' do
      result = wait_for_element_tool.execute({ selector: '#title', state: 'visible', timeout: 5 })

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('Element visible')
      expect(result[:data][:elapsed_seconds]).to be >= 0
    end

    it 'waits for element to exist' do
      result = wait_for_element_tool.execute({ selector: '#title', state: 'exists', timeout: 5 })

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('Element exists')
    end

    it 'waits for hidden element' do
      result = wait_for_element_tool.execute({ selector: '#hidden', state: 'hidden', timeout: 5 })

      expect(result[:success]).to be false
      expect(result[:error]).to include('Timeout')
    end

    it 'times out when element not found' do
      result = wait_for_element_tool.execute({ selector: '#non-existent', timeout: 2 })

      expect(result[:success]).to be false
      expect(result[:error]).to include('Timeout')
    end

    it 'uses default timeout when not specified' do
      result = wait_for_element_tool.execute({ selector: '#title' })

      expect(result[:success]).to be true
    end
  end

  describe FerrumMCP::Tools::WaitTool do
    it 'waits for specified seconds' do
      start_time = Time.now
      result = wait_tool.execute({ seconds: 1 })
      elapsed = Time.now - start_time

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('Waited 1 seconds')
      expect(elapsed).to be >= 1
      expect(elapsed).to be < 1.5
    end

    it 'waits for fractional seconds' do
      start_time = Time.now
      result = wait_tool.execute({ seconds: 0.5 })
      elapsed = Time.now - start_time

      expect(result[:success]).to be true
      expect(elapsed).to be >= 0.5
      expect(elapsed).to be < 1
    end
  end
end
