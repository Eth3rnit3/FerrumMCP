# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Extraction Tools' do
  let(:config) { test_config }
  let(:browser_manager) { FerrumMCP::BrowserManager.new(config) }
  let(:navigate_tool) { FerrumMCP::Tools::NavigateTool.new(browser_manager) }
  let(:get_text_tool) { FerrumMCP::Tools::GetTextTool.new(browser_manager) }
  let(:get_html_tool) { FerrumMCP::Tools::GetHTMLTool.new(browser_manager) }
  let(:screenshot_tool) { FerrumMCP::Tools::ScreenshotTool.new(browser_manager) }
  let(:get_title_tool) { FerrumMCP::Tools::GetTitleTool.new(browser_manager) }
  let(:get_url_tool) { FerrumMCP::Tools::GetURLTool.new(browser_manager) }

  before do
    browser_manager.start
    navigate_tool.execute({ url: test_url })
  end

  after do
    browser_manager.stop
  end

  describe FerrumMCP::Tools::GetTextTool do
    it 'gets text from a single element' do
      result = get_text_tool.execute({ selector: '#title' })

      expect(result[:success]).to be true
      expect(result[:data][:text]).to eq('Test Page')
    end

    it 'gets text from multiple elements' do
      result = get_text_tool.execute({ selector: 'p', multiple: true })

      expect(result[:success]).to be true
      expect(result[:data][:texts]).to be_an(Array)
      expect(result[:data][:count]).to be > 0
    end

    it 'returns error when element not found' do
      result = get_text_tool.execute({ selector: '#non-existent' })

      expect(result[:success]).to be false
    end
  end

  describe FerrumMCP::Tools::GetHTMLTool do
    it 'gets HTML of a specific element' do
      result = get_html_tool.execute({ selector: '#title' })

      expect(result[:success]).to be true
      expect(result[:data][:html]).to include('Test Page')
      expect(result[:data][:selector]).to eq('#title')
    end

    it 'gets full page HTML when no selector provided' do
      result = get_html_tool.execute({})

      expect(result[:success]).to be true
      expect(result[:data][:html]).to include('<html>')
      expect(result[:data][:html]).to include('Test Page')
      expect(result[:data][:url]).to eq(test_url)
    end
  end

  describe FerrumMCP::Tools::ScreenshotTool do
    it 'takes a PNG screenshot' do
      result = screenshot_tool.execute({ format: 'png' })

      expect(result[:success]).to be true
      expect(result[:type]).to eq('image')
      expect(result[:data]).to be_a(String)
      expect(result[:mime_type]).to eq('image/png')

      # Verify it's valid base64
      expect { Base64.decode64(result[:data]) }.not_to raise_error
    end

    it 'takes a JPEG screenshot' do
      result = screenshot_tool.execute({ format: 'jpeg' })

      expect(result[:success]).to be true
      expect(result[:mime_type]).to eq('image/jpeg')
    end

    it 'takes a full page screenshot' do
      result = screenshot_tool.execute({ full_page: true })

      expect(result[:success]).to be true
      expect(result[:data]).to be_a(String)
    end

    it 'takes screenshot of specific element' do
      result = screenshot_tool.execute({ selector: '#title' })

      expect(result[:success]).to be true
      expect(result[:data]).to be_a(String)
    end
  end

  describe FerrumMCP::Tools::GetTitleTool do
    it 'gets page title' do
      result = get_title_tool.execute({})

      expect(result[:success]).to be true
      expect(result[:data][:title]).to eq('Test Page')
      expect(result[:data][:url]).to eq(test_url)
    end
  end

  describe FerrumMCP::Tools::GetURLTool do
    it 'gets current URL' do
      result = get_url_tool.execute({})

      expect(result[:success]).to be true
      expect(result[:data][:url]).to eq(test_url)
    end
  end
end
