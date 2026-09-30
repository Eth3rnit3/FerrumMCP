# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe 'Page Tools (scroll, select, upload, viewport, tabs)' do
  let(:config) { FerrumMCP::Configuration.new }
  let(:session_manager) { FerrumMCP::SessionManager.new(config) }

  after { session_manager.shutdown }

  def run_tool(tool_class, sid, params = {})
    session_manager.with_session(sid) { |bm| tool_class.new(bm).execute(params.merge(session_id: sid)) }
  end

  def evaluate(sid, expression)
    run_tool(FerrumMCP::Tools::EvaluateJSTool, sid, expression: expression)[:data][:result]
  end

  describe FerrumMCP::Tools::ScrollTool do
    it 'scrolls the window by a direction and amount' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      result = run_tool(described_class, sid, direction: 'down', amount: 500)

      expect(result[:success]).to be true
      expect(result[:data][:y]).to be >= 500
      expect(evaluate(sid, 'window.scrollY')).to be >= 500
    end

    it 'scrolls to the bottom and back to the top' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      bottom = run_tool(described_class, sid, direction: 'bottom')
      top = run_tool(described_class, sid, direction: 'top')

      expect(bottom[:data][:y]).to be > 1000
      expect(top[:data][:y]).to eq(0)
    end

    it 'scrolls an element into view' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      result = run_tool(described_class, sid, selector: '#bottom-marker')

      expect(result[:success]).to be true
      expect(evaluate(sid, 'window.scrollY')).to be > 1000
    end

    it 'scrolls inside a scrollable container' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      result = run_tool(described_class, sid, selector: '#scroll-box', direction: 'down', amount: 300)

      expect(result[:success]).to be true
      expect(evaluate(sid, "document.querySelector('#scroll-box').scrollTop")).to be >= 300
    end
  end

  describe FerrumMCP::Tools::SelectOptionTool do
    it 'selects by value and fires change events' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      result = run_tool(described_class, sid, selector: '#plan', value: 'pro')

      expect(result[:success]).to be true
      expect(result[:data][:selected]).to eq([{ value: 'pro', label: 'Pro plan' }])
      expect(evaluate(sid, "document.querySelector('#status').textContent")).to eq('plan:pro')
    end

    it 'selects by label' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      result = run_tool(described_class, sid, selector: '#plan', label: 'Team')

      expect(result[:data][:selected].first[:value]).to eq('team')
    end

    it 'selects several values in a multiple select' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      result = run_tool(described_class, sid, selector: '#tags', values: %w[a c])

      expect(result[:data][:selected].map { |o| o[:value] }).to eq(%w[a c])
    end

    it 'fails clearly when no option matches' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      result = run_tool(described_class, sid, selector: '#plan', value: 'enterprise')

      expect(result[:success]).to be false
      expect(result[:error]).to include('No option')
    end
  end

  describe FerrumMCP::Tools::UploadFileTool do
    it 'attaches files from an allowed directory' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')
      path = File.join(Dir.tmpdir, "ferrum-upload-#{Process.pid}.txt")
      File.write(path, 'hello')

      result = run_tool(described_class, sid, selector: '#avatar', paths: [path])

      expect(result[:success]).to be true
      expect(evaluate(sid, "document.querySelector('#status').textContent")).to eq("files:#{File.basename(path)}")
    ensure
      FileUtils.rm_f(path)
    end

    it 'refuses files outside the allowed directories' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      result = run_tool(described_class, sid, selector: '#avatar', paths: ['/etc/hosts'])

      expect(result[:success]).to be false
      expect(result[:error]).to include('not allowed')
    end

    it 'refuses missing files' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      result = run_tool(described_class, sid, selector: '#avatar', paths: [File.join(Dir.tmpdir, 'missing.txt')])

      expect(result[:success]).to be false
      expect(result[:error]).to include('not found')
    end
  end

  describe FerrumMCP::Tools::SetViewportTool do
    it 'changes the viewport size' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      result = run_tool(described_class, sid, width: 500, height: 700)

      expect(result[:success]).to be true
      expect(evaluate(sid, 'window.innerWidth')).to eq(500)
      expect(evaluate(sid, 'window.innerHeight')).to eq(700)
    end
  end

  describe 'tabs' do
    it 'follows a link that opens a new tab, as a user lands on it' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      result = run_tool(FerrumMCP::Tools::ClickTool, sid, selector: '#blank-link')

      expect(result[:data][:new_tab]).to include(url: include('/fixtures/navigation/page2'))
      expect(run_tool(FerrumMCP::Tools::GetURLTool, sid)[:data][:url]).to include('/fixtures/navigation/page2')
    end

    it 'follows a tab opened by a script' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      result = run_tool(FerrumMCP::Tools::ClickTool, sid, selector: '#script-tab')

      expect(result[:data][:new_tab]).to include(url: include('/fixtures/navigation/page3'))
      expect(run_tool(FerrumMCP::Tools::GetURLTool, sid)[:data][:url]).to include('/fixtures/navigation/page3')
    end

    it 'stays on the tab when the click opens nothing' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      result = run_tool(FerrumMCP::Tools::ClickTool, sid, selector: '#custom-role')

      expect(result[:data]).not_to have_key(:new_tab)
      expect(run_tool(FerrumMCP::Tools::GetURLTool, sid)[:data][:url]).to include('agent_page')
    end

    # rubocop:disable RSpec/MultipleExpectations
    it 'opens, lists, switches and closes tabs' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      opened = run_tool(FerrumMCP::Tools::NewTabTool, sid, url: test_url('/fixtures/navigation/page2'))
      expect(opened[:success]).to be true
      expect(run_tool(FerrumMCP::Tools::GetTitleTool, sid)[:data][:title]).to eq('Navigation Test - Page 2')

      listed = run_tool(FerrumMCP::Tools::ListTabsTool, sid)
      expect(listed[:data][:count]).to eq(2)
      current = listed[:data][:tabs].find { |t| t[:current] }
      expect(current[:tab_id]).to eq(opened[:data][:tab_id])

      first_tab = listed[:data][:tabs].find { |t| !t[:current] }
      switched = run_tool(FerrumMCP::Tools::SwitchTabTool, sid, tab_id: first_tab[:tab_id])
      expect(switched[:success]).to be true
      expect(run_tool(FerrumMCP::Tools::GetTitleTool, sid)[:data][:title]).to eq('Agent Tools Test Page')

      closed = run_tool(FerrumMCP::Tools::CloseTabTool, sid, tab_id: opened[:data][:tab_id])
      expect(closed[:success]).to be true
      expect(run_tool(FerrumMCP::Tools::ListTabsTool, sid)[:data][:count]).to eq(1)
    end
    # rubocop:enable RSpec/MultipleExpectations

    it 'switches to a tab by index and falls back to another tab when the current one is closed' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')
      run_tool(FerrumMCP::Tools::NewTabTool, sid)

      expect(run_tool(FerrumMCP::Tools::SwitchTabTool, sid, index: 0)[:success]).to be true
      closed = run_tool(FerrumMCP::Tools::CloseTabTool, sid)

      expect(closed[:success]).to be true
      expect(run_tool(FerrumMCP::Tools::GetTitleTool, sid)[:success]).to be true
    end

    it 'refuses to close the last tab' do
      sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

      result = run_tool(FerrumMCP::Tools::CloseTabTool, sid)

      expect(result[:success]).to be false
      expect(result[:error]).to include('last tab')
    end
  end
end
