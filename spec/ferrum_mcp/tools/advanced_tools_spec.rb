# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Advanced Tools' do
  let(:config) { test_config }
  let(:browser_manager) { FerrumMCP::BrowserManager.new(config) }
  let(:navigate_tool) { FerrumMCP::Tools::NavigateTool.new(browser_manager) }
  let(:execute_script_tool) { FerrumMCP::Tools::ExecuteScriptTool.new(browser_manager) }
  let(:evaluate_js_tool) { FerrumMCP::Tools::EvaluateJSTool.new(browser_manager) }
  let(:get_cookies_tool) { FerrumMCP::Tools::GetCookiesTool.new(browser_manager) }
  let(:set_cookie_tool) { FerrumMCP::Tools::SetCookieTool.new(browser_manager) }
  let(:clear_cookies_tool) { FerrumMCP::Tools::ClearCookiesTool.new(browser_manager) }
  let(:get_attribute_tool) { FerrumMCP::Tools::GetAttributeTool.new(browser_manager) }

  before(:each) do
    browser_manager.start
    navigate_tool.execute({ url: test_url })
  end

  after(:each) do
    browser_manager.stop
  end

  describe FerrumMCP::Tools::ExecuteScriptTool do
    it 'executes JavaScript code' do
      result = execute_script_tool.execute({ script: 'document.title = "Modified Title";' })

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('Script executed successfully')
    end

    it 'executes complex script' do
      script = <<~JS
        const elem = document.createElement('div');
        elem.id = 'new-element';
        document.body.appendChild(elem);
      JS

      result = execute_script_tool.execute({ script: script })

      expect(result[:success]).to be true
    end
  end

  describe FerrumMCP::Tools::EvaluateJSTool do
    it 'evaluates JavaScript and returns result' do
      result = evaluate_js_tool.execute({ expression: 'document.title' })

      expect(result[:success]).to be true
      expect(result[:data][:result]).to eq('Test Page')
    end

    it 'evaluates arithmetic expression' do
      result = evaluate_js_tool.execute({ expression: '2 + 2' })

      expect(result[:success]).to be true
      expect(result[:data][:result]).to eq(4)
    end

    it 'evaluates DOM query' do
      result = evaluate_js_tool.execute({ expression: 'document.querySelectorAll("p").length' })

      expect(result[:success]).to be true
      expect(result[:data][:result]).to be > 0
    end
  end

  describe FerrumMCP::Tools::GetCookiesTool do
    it 'gets all cookies' do
      # Set a cookie first
      set_cookie_tool.execute({
                                name: 'test_cookie',
                                value: 'test_value',
                                domain: 'localhost'
                              })

      result = get_cookies_tool.execute({})

      expect(result[:success]).to be true
      expect(result[:data][:cookies]).to be_a(Hash)
      expect(result[:data][:count]).to be >= 0
    end

    it 'filters cookies by domain' do
      set_cookie_tool.execute({
                                name: 'test_cookie',
                                value: 'test_value',
                                domain: 'localhost'
                              })

      result = get_cookies_tool.execute({ domain: 'localhost' })

      expect(result[:success]).to be true
      expect(result[:data][:cookies]).to be_a(Hash)
    end
  end

  describe FerrumMCP::Tools::SetCookieTool do
    it 'sets a cookie' do
      result = set_cookie_tool.execute({
                                         name: 'my_cookie',
                                         value: 'my_value',
                                         domain: 'localhost',
                                         path: '/'
                                       })

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('Cookie set: my_cookie')
    end

    it 'sets cookie with security flags' do
      result = set_cookie_tool.execute({
                                         name: 'secure_cookie',
                                         value: 'secure_value',
                                         domain: 'localhost',
                                         secure: false,
                                         httponly: true
                                       })

      expect(result[:success]).to be true
    end
  end

  describe FerrumMCP::Tools::ClearCookiesTool do
    it 'clears all cookies' do
      # Set some cookies
      set_cookie_tool.execute({ name: 'cookie1', value: 'value1', domain: 'localhost' })
      set_cookie_tool.execute({ name: 'cookie2', value: 'value2', domain: 'localhost' })

      result = clear_cookies_tool.execute({})

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('All cookies cleared')

      # Verify cookies are cleared
      cookies_result = get_cookies_tool.execute({})
      expect(cookies_result[:data][:count]).to eq(0)
    end

    it 'clears cookies for specific domain' do
      # Set cookies
      set_cookie_tool.execute({ name: 'test_cookie', value: 'test_value', domain: 'localhost' })

      result = clear_cookies_tool.execute({ domain: 'localhost' })

      expect(result[:success]).to be true
      expect(result[:data][:message]).to include('Cleared')
    end
  end

  describe FerrumMCP::Tools::GetAttributeTool do
    it 'gets attribute from element' do
      result = get_attribute_tool.execute({ selector: '#name-input', attribute: 'placeholder' })

      expect(result[:success]).to be true
      expect(result[:data][:selector]).to eq('#name-input')
      expect(result[:data][:attribute]).to eq('placeholder')
      expect(result[:data][:value]).to eq('Enter name')
    end

    it 'gets id attribute' do
      result = get_attribute_tool.execute({ selector: '#title', attribute: 'id' })

      expect(result[:success]).to be true
      expect(result[:data][:value]).to eq('title')
    end

    it 'returns error when element not found' do
      result = get_attribute_tool.execute({ selector: '#non-existent', attribute: 'id' })

      expect(result[:success]).to be false
    end
  end
end
