# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Advanced Tools' do
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

  describe FerrumMCP::Tools::ExecuteScriptTool do
    describe '.tool_name' do
      it 'returns execute_script' do
        expect(described_class.tool_name).to eq('execute_script')
      end
    end

    describe '#execute' do
      it 'executes JavaScript code' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, script: 'document.title = "Modified Title";' }
        )

        expect(result[:success]).to be true
        expect(result[:data][:message]).to include('Script executed successfully')

        # Verify the script executed
        session_manager.with_session(sid) do |browser_manager|
          expect(browser_manager.browser.evaluate('document.title')).to eq('Modified Title')
        end
      end

      it 'executes complex script' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        script = <<~JS
          const elem = document.createElement('div');
          elem.id = 'new-element';
          elem.textContent = 'Dynamic Element';
          document.body.appendChild(elem);
        JS

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, script: script }
        )

        expect(result[:success]).to be true

        # Verify element was created
        session_manager.with_session(sid) do |browser_manager|
          new_elem = browser_manager.browser.at_css('#new-element')
          expect(new_elem).not_to be_nil
          expect(new_elem.text).to eq('Dynamic Element')
        end
      end
    end
  end

  describe FerrumMCP::Tools::EvaluateJSTool do
    describe '.tool_name' do
      it 'returns evaluate_js' do
        expect(described_class.tool_name).to eq('evaluate_js')
      end
    end

    describe '#execute' do
      it 'evaluates JavaScript and returns result' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, expression: 'document.title' }
        )

        expect(result[:success]).to be true
        expect(result[:data][:result]).to eq('Test Page')
      end

      it 'evaluates arithmetic expression' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, expression: '2 + 2' }
        )

        expect(result[:success]).to be true
        expect(result[:data][:result]).to eq(4)
      end

      it 'evaluates DOM query' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, expression: 'document.querySelectorAll("p").length' }
        )

        expect(result[:success]).to be true
        expect(result[:data][:result]).to eq(3)
      end
    end
  end

  describe FerrumMCP::Tools::GetCookiesTool do
    describe '.tool_name' do
      it 'returns get_cookies' do
        expect(described_class.tool_name).to eq('get_cookies')
      end
    end

    describe '#execute' do
      it 'gets all cookies' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        # Set a cookie first
        execute_tool_in_session(
          FerrumMCP::Tools::SetCookieTool,
          sid,
          {
            session_id: sid,
            name: 'test_cookie',
            value: 'test_value',
            domain: 'localhost'
          }
        )

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid }
        )

        expect(result[:success]).to be true
        expect(result[:data][:cookies]).to be_an(Array)
        expect(result[:data][:count]).to be >= 1
      end

      it 'returns success when filtering cookies by domain' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        execute_tool_in_session(
          FerrumMCP::Tools::SetCookieTool,
          sid,
          {
            session_id: sid,
            name: 'test_cookie',
            value: 'test_value',
            domain: 'localhost'
          }
        )

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, domain: 'localhost' }
        )

        expect(result[:success]).to be true
        expect(result[:data][:cookies]).to be_an(Array)
      end
    end
  end

  describe FerrumMCP::Tools::SetCookieTool do
    describe '.tool_name' do
      it 'returns set_cookie' do
        expect(described_class.tool_name).to eq('set_cookie')
      end
    end

    describe '#execute' do
      it 'sets a cookie' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        result = execute_tool_in_session(
          described_class,
          sid,
          {
            session_id: sid,
            name: 'my_cookie',
            value: 'my_value',
            domain: 'localhost',
            path: '/'
          }
        )

        expect(result[:success]).to be true
        expect(result[:data][:message]).to include('Cookie set: my_cookie')
      end

      it 'sets cookie with security flags' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        result = execute_tool_in_session(
          described_class,
          sid,
          {
            session_id: sid,
            name: 'secure_cookie',
            value: 'secure_value',
            domain: 'localhost',
            secure: false,
            httponly: true
          }
        )

        expect(result[:success]).to be true
      end
    end
  end

  describe FerrumMCP::Tools::ClearCookiesTool do
    describe '.tool_name' do
      it 'returns clear_cookies' do
        expect(described_class.tool_name).to eq('clear_cookies')
      end
    end

    describe '#execute' do
      it 'clears all cookies' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        # Set some cookies
        execute_tool_in_session(
          FerrumMCP::Tools::SetCookieTool,
          sid,
          { session_id: sid, name: 'cookie1', value: 'value1', domain: 'localhost' }
        )
        execute_tool_in_session(
          FerrumMCP::Tools::SetCookieTool,
          sid,
          { session_id: sid, name: 'cookie2', value: 'value2', domain: 'localhost' }
        )

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid }
        )

        expect(result[:success]).to be true
        expect(result[:data][:message]).to include('All cookies cleared')

        # Verify cookies are cleared
        cookies_result = execute_tool_in_session(
          FerrumMCP::Tools::GetCookiesTool,
          sid,
          { session_id: sid }
        )
        expect(cookies_result[:data][:count]).to eq(0)
      end

      it 'clears cookies for specific domain' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        # Set cookies
        execute_tool_in_session(
          FerrumMCP::Tools::SetCookieTool,
          sid,
          { session_id: sid, name: 'test_cookie', value: 'test_value', domain: 'localhost' }
        )

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, domain: 'localhost' }
        )

        expect(result[:success]).to be true
        expect(result[:data][:message]).to include('Cleared')
      end
    end
  end

  describe FerrumMCP::Tools::GetAttributeTool do
    describe '.tool_name' do
      it 'returns get_attribute' do
        expect(described_class.tool_name).to eq('get_attribute')
      end
    end

    describe '#execute' do
      it 'gets attribute from element' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, selector: '#name-input', attribute: 'placeholder' }
        )

        expect(result[:success]).to be true
        expect(result[:data][:selector]).to eq('#name-input')
        expect(result[:data][:attribute]).to eq('placeholder')
        expect(result[:data][:value]).to eq('Enter name')
      end

      it 'gets id attribute' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, selector: '#title', attribute: 'id' }
        )

        expect(result[:success]).to be true
        expect(result[:data][:value]).to eq('title')
      end

      it 'gets data attribute' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, selector: '#data-element', attribute: 'data-id' }
        )

        expect(result[:success]).to be true
        expect(result[:data][:value]).to eq('123')
      end

      it 'returns error when element not found' do
        sid = setup_session_with_fixture(session_manager, 'advanced_page.html', subdir: 'advanced')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, selector: '#non-existent', attribute: 'id' }
        )

        expect(result[:success]).to be false
        expect(result[:error]).to include('Element not found')
      end
    end
  end
end
