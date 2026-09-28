# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FerrumMCP::CLI::CommandHandler do
  describe '.start_server' do
    let(:runner) { instance_double(FerrumMCP::CLI::ServerRunner, start: nil) }
    let(:options) { { transport: 'http', host: '127.0.0.1', port: 3001, log_level: 'error' } }

    before do
      allow(FerrumMCP::CLI::ServerRunner).to receive(:new).and_return(runner)
      allow(described_class).to receive(:require).and_call_original
    end

    around do |example|
      saved = ENV.slice('MCP_SERVER_HOST', 'MCP_SERVER_PORT', 'LOG_LEVEL')
      example.run
    ensure
      %w[MCP_SERVER_HOST MCP_SERVER_PORT LOG_LEVEL].each { |k| ENV.delete(k) }
      saved.each { |k, v| ENV[k] = v }
    end

    it 'does not load bundler/setup, so the installed gem works outside a Bundler project' do
      described_class.start_server(options)

      expect(described_class).not_to have_received(:require).with('bundler/setup')
    end

    it 'starts the runner with the given options' do
      described_class.start_server(options)

      expect(FerrumMCP::CLI::ServerRunner).to have_received(:new).with(options)
      expect(runner).to have_received(:start)
    end
  end
end
