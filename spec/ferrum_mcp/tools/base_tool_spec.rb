# frozen_string_literal: true

require 'spec_helper'

# Unit spec: the browser is faked, no Chrome involved.
RSpec.describe FerrumMCP::Tools::BaseTool, integration: false do
  let(:config) { FerrumMCP::Configuration.new }
  let(:fake_browser) { instance_double(Ferrum::Browser, quit: nil, process: nil) }
  let(:server) { FerrumMCP::Server.new(config) }
  let(:session_manager) { server.session_manager }
  let(:session_id) { session_manager.create_session }

  let(:failing_tool) do
    Class.new(described_class) do
      tool_name 'failing_tool'
      description 'Raises whatever error it is given'

      param :error, type: :string, description: 'Error class name'

      def perform(params)
        raise Object.const_get(params[:error]), 'boom'
      end
    end
  end

  before do
    allow(Ferrum::Browser).to receive(:new).and_return(fake_browser)
  end

  after do
    session_manager.shutdown
  end

  def run_tool(error)
    session_manager.with_session(session_id) { |manager| failing_tool.new(manager).execute(error: error) }
  end

  describe '#execute' do
    it 'turns an unexpected error into an error response naming the tool' do
      result = run_tool('RuntimeError')

      expect(result).to include(success: false, error: 'failing_tool failed: boom')
    end

    it 'turns a ToolError into an error response' do
      result = run_tool('FerrumMCP::ToolError')

      expect(result).to include(success: false, error: 'failing_tool failed: boom')
    end

    it 'lets a dead browser error reach the session' do
      expect { run_tool('Ferrum::DeadBrowserError') }.to raise_error(Ferrum::DeadBrowserError)
      expect(session_manager.get_session(session_id).active?).to be(false)
    end

    it 'does not let a shipped tool swallow a dead browser error' do
      allow(fake_browser).to receive(:page).and_raise(Ferrum::DeadBrowserError)

      expect do
        session_manager.with_session(session_id) { |manager| FerrumMCP::Tools::GetTitleTool.new(manager).execute({}) }
      end.to raise_error(Ferrum::DeadBrowserError)
      expect(session_manager.get_session(session_id).active?).to be(false)
    end
  end

  describe 'through the server' do
    it 'answers a tool error response and marks the session inactive on a dead browser' do
      response = server.send(:execute_tool, failing_tool, { session_id: session_id, error: 'Ferrum::DeadBrowserError' })

      expect(response).to be_a(MCP::Tool::Response)
      expect(response.error?).to be(true)
      expect(session_manager.get_session(session_id).active?).to be(false)
    end
  end

  # Long tools (solve_captcha) report where they are; the MCP SDK hands the
  # notification channel to the tool block as server_context.
  describe 'progress reporting' do
    let(:slow_tool) do
      Class.new(described_class) do
        tool_name 'slow_tool'
        description 'Reports progress'

        def perform(_params)
          report_progress(1, total: 2, message: 'half way')
          success_response(done: true)
        end
      end
    end
    let(:server_context) { instance_double(MCP::ServerContext, report_progress: nil) }

    it 'forwards report_progress to the MCP server context' do
      server.send(:execute_tool, slow_tool, { session_id: session_id, server_context: server_context })

      expect(server_context).to have_received(:report_progress).with(1, total: 2, message: 'half way')
    end

    it 'is a no-op when the client asked for no progress' do
      response = server.send(:execute_tool, slow_tool, { session_id: session_id })

      expect(response.error?).to be(false)
    end
  end
end
