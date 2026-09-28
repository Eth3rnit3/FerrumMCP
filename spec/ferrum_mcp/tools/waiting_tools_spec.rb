# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Waiting Tools' do
  let(:config) { FerrumMCP::Configuration.new }
  let(:session_manager) { FerrumMCP::SessionManager.new(config) }

  after { session_manager.shutdown }

  def run_tool(tool_class, sid, params)
    session_manager.with_session(sid) { |bm| tool_class.new(bm).execute(params.merge(session_id: sid)) }
  end

  def click_submit(sid)
    run_tool(FerrumMCP::Tools::ClickTool, sid, selector: '#submit-btn')
  end

  describe FerrumMCP::Tools::WaitForSelectorTool do
    it 'declares its interface' do
      expect(described_class.tool_name).to eq('wait_for_selector')
      expect(described_class.input_schema[:required]).to include('session_id', 'selector')
    end

    it 'waits for an element that appears later' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')
      click_submit(sid)

      result = run_tool(described_class, sid, selector: '#late-btn', timeout: 5)

      expect(result[:success]).to be true
      expect(result[:data][:found]).to be true
      expect(result[:data][:elapsed_ms]).to be > 100
    end

    it 'times out when the element never appears' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      result = run_tool(described_class, sid, selector: '#never', timeout: 0.5)

      expect(result[:success]).to be false
      expect(result[:error]).to include('Timed out')
    end

    it 'waits for an element to be removed with state detached' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')
      click_submit(sid)

      result = run_tool(described_class, sid, selector: '#removable', state: 'detached', timeout: 5)

      expect(result[:success]).to be true
    end

    it 'treats hidden elements as not visible by default' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      result = run_tool(described_class, sid, selector: '#hidden-btn', timeout: 0.3)
      attached = run_tool(described_class, sid, selector: '#hidden-btn', state: 'attached', timeout: 0.3)

      expect(result[:success]).to be false
      expect(attached[:success]).to be true
    end
  end

  describe FerrumMCP::Tools::WaitForTextTool do
    it 'waits for text to appear anywhere on the page' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')
      click_submit(sid)

      result = run_tool(described_class, sid, text: 'Late button', timeout: 5)

      expect(result[:success]).to be true
    end

    it 'scopes the search to a selector' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')
      click_submit(sid)

      result = run_tool(described_class, sid, text: 'ready', selector: '#status', timeout: 5)

      expect(result[:success]).to be true
      expect(result[:data][:selector]).to eq('#status')
    end

    it 'times out when the text never appears' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      result = run_tool(described_class, sid, text: 'nope nope nope', timeout: 0.5)

      expect(result[:success]).to be false
    end
  end

  describe FerrumMCP::Tools::WaitForNetworkIdleTool do
    it 'returns once the network is idle' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      result = run_tool(described_class, sid, timeout: 5)

      expect(result[:success]).to be true
      expect(result[:data][:idle]).to be true
    end
  end
end
