# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Interaction Tools' do
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

  describe FerrumMCP::Tools::ClickTool do
    describe '.tool_name' do
      it 'returns click' do
        expect(described_class.tool_name).to eq('click')
      end
    end

    describe '#execute' do
      it 'clicks on a button element' do
        sid = setup_session_with_fixture(session_manager, 'form_page.html', subdir: 'interaction')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, selector: '#click-test' }
        )

        expect(result[:success]).to be true
        expect(result[:data][:message]).to include('Clicked')

        # Verify the click worked
        session_manager.with_session(sid) do |browser_manager|
          results = browser_manager.browser.at_css('#results')
          expect(results.attribute('data-action')).to eq('clicked')
        end
      end

      it 'clicks on a link element' do
        sid = setup_session_with_fixture(session_manager, 'links_page.html', subdir: 'interaction')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, selector: '#javascript-link' }
        )

        expect(result[:success]).to be true

        # Verify the click worked
        session_manager.with_session(sid) do |browser_manager|
          click_result = browser_manager.browser.at_css('#click-result')
          expect(click_result.attribute('data-clicked')).to eq('true')
        end
      end

      it 'returns error when element not found' do
        sid = setup_session_with_fixture(session_manager, 'form_page.html', subdir: 'interaction')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, selector: '#non-existent-element' }
        )

        expect(result[:success]).to be false
        expect(result[:error]).to include('Element not found')
      end

      it 'waits for element with custom timeout' do
        sid = setup_session_with_fixture(session_manager, 'form_page.html', subdir: 'interaction')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, selector: '#click-test', wait: 10 }
        )

        expect(result[:success]).to be true
      end
    end
  end

  describe FerrumMCP::Tools::FillFormTool do
    describe '.tool_name' do
      it 'returns fill_form' do
        expect(described_class.tool_name).to eq('fill_form')
      end
    end

    describe '#execute' do
      it 'fills single form field' do
        sid = setup_session_with_fixture(session_manager, 'form_page.html', subdir: 'interaction')

        fields = [{ selector: '#name-input', value: 'John Doe' }]

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, fields: fields }
        )

        expect(result[:success]).to be true
        expect(result[:data][:fields].length).to eq(1)
        expect(result[:data][:fields][0][:filled]).to be true

        # Verify the value was set
        session_manager.with_session(sid) do |browser_manager|
          value = browser_manager.browser.at_css('#name-input').property('value')
          expect(value).to eq('John Doe')
        end
      end

      # rubocop:disable RSpec/MultipleExpectations
      it 'fills multiple form fields' do
        sid = setup_session_with_fixture(session_manager, 'form_page.html', subdir: 'interaction')

        fields = [
          { selector: '#name-input', value: 'John Doe' },
          { selector: '#email-input', value: 'john@example.com' },
          { selector: '#message-textarea', value: 'Hello World' }
        ]

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, fields: fields }
        )

        expect(result[:success]).to be true
        expect(result[:data][:fields].length).to eq(3)
        expect(result[:data][:fields]).to all(satisfy { |f| f[:filled] == true })

        # Verify all values were set
        session_manager.with_session(sid) do |browser_manager|
          expect(browser_manager.browser.at_css('#name-input').property('value')).to eq('John Doe')
          expect(browser_manager.browser.at_css('#email-input').property('value')).to eq('john@example.com')
          expect(browser_manager.browser.at_css('#message-textarea').property('value')).to eq('Hello World')
        end
      end
      # rubocop:enable RSpec/MultipleExpectations

      it 'handles select elements' do
        sid = setup_session_with_fixture(session_manager, 'form_page.html', subdir: 'interaction')

        fields = [{ selector: '#country-select', value: 'fr' }]

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, fields: fields }
        )

        expect(result[:success]).to be true

        # Verify the select value
        session_manager.with_session(sid) do |browser_manager|
          value = browser_manager.browser.at_css('#country-select').property('value')
          expect(value).to eq('fr')
        end
      end

      it 'returns error when field not found' do
        sid = setup_session_with_fixture(session_manager, 'form_page.html', subdir: 'interaction')

        fields = [{ selector: '#non-existent-field', value: 'test' }]

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, fields: fields }
        )

        expect(result[:success]).to be false
        expect(result[:error]).to be_a(String)
      end
    end
  end

  describe FerrumMCP::Tools::PressKeyTool do
    describe '.tool_name' do
      it 'returns press_key' do
        expect(described_class.tool_name).to eq('press_key')
      end
    end

    describe '#execute' do
      it 'presses Enter key globally' do
        sid = setup_session_with_fixture(session_manager, 'form_page.html', subdir: 'interaction')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, key: 'Enter' }
        )

        expect(result[:success]).to be true
        expect(result[:data][:message]).to include('Pressed key: Enter')
      end

      it 'presses key on focused element' do
        sid = setup_session_with_fixture(session_manager, 'form_page.html', subdir: 'interaction')

        # Focus the name input first
        session_manager.with_session(sid) do |browser_manager|
          browser_manager.browser.at_css('#name-input').focus
        end

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, key: 'Enter', selector: '#name-input' }
        )

        expect(result[:success]).to be true
      end

      it 'presses Tab key' do
        sid = setup_session_with_fixture(session_manager, 'form_page.html', subdir: 'interaction')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, key: 'Tab' }
        )

        expect(result[:success]).to be true
        expect(result[:data][:message]).to include('Pressed key: Tab')
      end
    end
  end

  describe FerrumMCP::Tools::HoverTool do
    describe '.tool_name' do
      it 'returns hover' do
        expect(described_class.tool_name).to eq('hover')
      end
    end

    describe '#execute' do
      it 'hovers over an element' do
        sid = setup_session_with_fixture(session_manager, 'form_page.html', subdir: 'interaction')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, selector: '#hover-zone' }
        )

        expect(result[:success]).to be true
        expect(result[:data][:message]).to include('Hovered')
      end

      it 'returns error when element not found' do
        sid = setup_session_with_fixture(session_manager, 'form_page.html', subdir: 'interaction')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, selector: '#non-existent' }
        )

        expect(result[:success]).to be false
        expect(result[:error]).to include('Element not found')
      end
    end
  end

  describe 'interaction integration scenarios' do
    it 'fills and submits a complete form' do
      sid = setup_session_with_fixture(session_manager, 'form_page.html', subdir: 'interaction')

      # Fill all form fields
      fields = [
        { selector: '#name-input', value: 'Jane Smith' },
        { selector: '#email-input', value: 'jane@example.com' },
        { selector: '#country-select', value: 'uk' },
        { selector: '#message-textarea', value: 'Test message' }
      ]

      fill_result = execute_tool_in_session(
        FerrumMCP::Tools::FillFormTool,
        sid,
        { session_id: sid, fields: fields }
      )

      expect(fill_result[:success]).to be true

      # Click the submit button
      click_result = execute_tool_in_session(
        FerrumMCP::Tools::ClickTool,
        sid,
        { session_id: sid, selector: '#submit-button' }
      )

      expect(click_result[:success]).to be true

      # Verify form was submitted
      session_manager.with_session(sid) do |browser_manager|
        status = browser_manager.browser.at_css('#status')
        expect(status.attribute('data-status')).to eq('submitted')
      end
    end

    it 'handles complex interaction sequence' do
      sid = setup_session_with_fixture(session_manager, 'form_page.html', subdir: 'interaction')

      # 1. Fill a field
      execute_tool_in_session(
        FerrumMCP::Tools::FillFormTool,
        sid,
        { session_id: sid, fields: [{ selector: '#name-input', value: 'Test User' }] }
      )

      # 2. Hover over an element
      execute_tool_in_session(
        FerrumMCP::Tools::HoverTool,
        sid,
        { session_id: sid, selector: '#hover-zone' }
      )

      # 3. Click a button
      execute_tool_in_session(
        FerrumMCP::Tools::ClickTool,
        sid,
        { session_id: sid, selector: '#click-test' }
      )

      # Verify all interactions worked
      session_manager.with_session(sid) do |browser_manager|
        expect(browser_manager.browser.at_css('#name-input').property('value')).to eq('Test User')
        expect(browser_manager.browser.at_css('#results').attribute('data-action')).to eq('clicked')
      end
    end
  end
end
