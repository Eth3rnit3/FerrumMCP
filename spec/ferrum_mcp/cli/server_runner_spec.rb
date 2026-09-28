# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FerrumMCP::CLI::ServerRunner do
  let(:transport) { instance_double(FerrumMCP::Transport::HTTPServer, start: nil, stop: nil) }
  let(:server) { instance_double(FerrumMCP::Server, shutdown: nil, stop_browser: nil) }
  let(:runner) { described_class.new(transport: 'http') }

  before do
    allow(FerrumMCP::Server).to receive(:new).and_return(server)
    allow(FerrumMCP::Transport::HTTPServer).to receive(:new).and_return(transport)
    # Never install real signal traps inside the test process
    allow(runner).to receive(:setup_signal_handlers)
  end

  describe '#shutdown' do
    it 'stops the transport and shuts the MCP server down without exiting the process' do
      runner.send(:setup_servers)

      expect { runner.send(:shutdown) }.not_to raise_error

      expect(transport).to have_received(:stop)
      expect(server).to have_received(:shutdown)
    end
  end

  describe '#start' do
    it 'shuts everything down when the main loop is interrupted by a signal' do
      thread = Thread.new { runner.start }
      thread.report_on_exception = false
      sleep 0.2

      thread.raise(Interrupt)
      begin
        thread.join(2)
      rescue Interrupt, SystemExit
        # the runner must handle the interruption itself
      end

      expect(transport).to have_received(:stop)
      expect(server).to have_received(:shutdown)
    end
  end
end
