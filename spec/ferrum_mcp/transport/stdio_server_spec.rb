# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'json'

RSpec.describe FerrumMCP::Transport::StdioServer do
  let(:config) { test_base_config }
  let(:mcp_server) { FerrumMCP::Server.new(config) }
  let(:stdio_server) { described_class.new(mcp_server, config) }

  describe '#initialize' do
    it 'creates a stdio server with MCP transport' do
      expect(stdio_server).to be_a(described_class)
      expect(stdio_server.mcp_transport).to be_a(MCP::Server::Transports::StdioTransport)
    end

    it 'creates and assigns the MCP transport' do
      # Verify the transport was created
      expect(stdio_server.mcp_transport).not_to be_nil
      expect(stdio_server.mcp_transport).to be_a(MCP::Server::Transports::StdioTransport)
    end

    it 'configures the logger' do
      expect(stdio_server.logger).to be_a(Logger)
    end
  end

  describe '#start and message handling' do
    it 'processes JSON-RPC requests from stdin' do
      # Mock stdin/stdout
      input = StringIO.new
      output = StringIO.new

      # Simulate initialize request
      initialize_request = {
        jsonrpc: '2.0',
        id: 0,
        method: 'initialize',
        params: {
          protocolVersion: '2025-06-18',
          capabilities: {},
          clientInfo: { name: 'test-client', version: '1.0' }
        }
      }

      input.puts(initialize_request.to_json)
      input.rewind

      # Temporarily replace stdin/stdout
      original_stdin = $stdin
      original_stdout = $stdout

      begin
        # rubocop:disable RSpec/ExpectOutput
        $stdin = input
        $stdout = output
        # rubocop:enable RSpec/ExpectOutput

        # Start server in a thread with timeout
        server_thread = Thread.new do
          stdio_server.start
        rescue StandardError
          # Expected to fail when input ends
        end

        # Wait a bit for processing
        sleep 0.5

        # Close stdin to end the loop
        input.close

        # Wait for thread to finish
        server_thread.join(2)

        # Verify output contains JSON-RPC response
        output.rewind
        response_line = output.gets
        expect(response_line).not_to be_nil
        response = JSON.parse(response_line)
        expect(response['jsonrpc']).to eq('2.0')
        expect(response['id']).to eq(0)
        expect(response['result']).to be_a(Hash)
      ensure
        # rubocop:disable RSpec/ExpectOutput
        $stdin = original_stdin
        $stdout = original_stdout
        # rubocop:enable RSpec/ExpectOutput
      end
    end

    it 'handles invalid JSON gracefully' do
      input = StringIO.new('invalid json')
      output = StringIO.new
      input.rewind

      original_stdin = $stdin
      original_stdout = $stdout

      begin
        # rubocop:disable RSpec/ExpectOutput
        $stdin = input
        $stdout = output
        # rubocop:enable RSpec/ExpectOutput

        server_thread = Thread.new do
          stdio_server.start
        rescue StandardError
          # Expected
        end

        sleep 0.5
        input.close
        server_thread.join(2)

        output.rewind
        response_line = output.gets
        expect(response_line).not_to be_nil
        response = JSON.parse(response_line)
        expect(response['error']).to be_a(Hash)
        expect(response['error']['code']).to eq(-32_700)
      ensure
        # rubocop:disable RSpec/ExpectOutput
        $stdin = original_stdin
        $stdout = original_stdout
        # rubocop:enable RSpec/ExpectOutput
      end
    end
  end

  describe '#start read loop' do
    it 'delegates the read loop to the MCP transport instead of reading stdin itself' do
      request = { jsonrpc: '2.0', id: 1, method: 'ping' }.to_json
      input = StringIO.new("#{request}\n")
      allow(stdio_server.mcp_transport).to receive(:open) # transport loop stubbed out

      original_stdin = $stdin
      begin
        $stdin = input
        stdio_server.start
      ensure
        $stdin = original_stdin
      end

      expect(stdio_server.mcp_transport).to have_received(:open)
      expect(input.pos).to eq(0)
    end

    it 'writes exactly one response line per request' do
      requests = [1, 2].map { |id| { jsonrpc: '2.0', id: id, method: 'ping' }.to_json }
      input = StringIO.new("#{requests.join("\n")}\n")
      output = StringIO.new

      original_stdin = $stdin
      original_stdout = $stdout
      begin
        # rubocop:disable RSpec/ExpectOutput
        $stdin = input
        $stdout = output
        # rubocop:enable RSpec/ExpectOutput
        stdio_server.start
      ensure
        # rubocop:disable RSpec/ExpectOutput
        $stdin = original_stdin
        $stdout = original_stdout
        # rubocop:enable RSpec/ExpectOutput
      end

      lines = output.string.lines.map(&:strip).reject(&:empty?)
      expect(lines.size).to eq(2)
      expect(lines.map { |l| JSON.parse(l)['id'] }).to eq([1, 2])
    end
  end

  describe '#stop' do
    it 'closes the MCP transport' do
      allow(stdio_server.mcp_transport).to receive(:close)
      stdio_server.stop
      expect(stdio_server.mcp_transport).to have_received(:close)
    end

    it 'logs shutdown message' do
      allow(stdio_server.logger).to receive(:info)
      stdio_server.stop
      expect(stdio_server.logger).to have_received(:info).with('Stopping STDIO server...')
      expect(stdio_server.logger).to have_received(:info).with('STDIO server stopped')
    end
  end
end
