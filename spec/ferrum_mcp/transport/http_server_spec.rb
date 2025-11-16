# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

RSpec.describe FerrumMCP::Transport::HTTPServer do
  include Rack::Test::Methods

  let(:config) { test_base_config }
  let(:mcp_server) { FerrumMCP::Server.new(config) }
  let(:http_server) { described_class.new(mcp_server, config) }

  def app
    http_server.app
  end

  describe '#initialize' do
    it 'creates an HTTP server with MCP transport' do
      expect(http_server).to be_a(described_class)
      expect(http_server.mcp_transport).to be_a(MCP::Server::Transports::StreamableHTTPTransport)
    end

    it 'creates and assigns the MCP transport' do
      # Verify the transport was created
      expect(http_server.mcp_transport).not_to be_nil
      expect(http_server.mcp_transport).to be_a(MCP::Server::Transports::StreamableHTTPTransport)
    end

    it 'configures the logger' do
      expect(http_server.logger).to be_a(Logger)
    end
  end

  describe 'Rack app' do
    describe 'GET /' do
      it 'returns server information' do
        get '/'
        expect(last_response).to be_ok
        expect(last_response.content_type).to include('application/json')

        body = JSON.parse(last_response.body)
        expect(body['name']).to eq('Ferrum MCP Server')
        expect(body['version']).to eq(FerrumMCP::VERSION)
        expect(body['endpoints']).to include('mcp' => '/mcp', 'health' => '/health')
      end
    end

    describe 'GET /health' do
      it 'returns health status' do
        get '/health'
        expect(last_response).to be_ok
        expect(last_response.content_type).to include('application/json')

        body = JSON.parse(last_response.body)
        expect(body['status']).to eq('ok')
      end
    end

    describe 'POST /mcp' do
      it 'handles MCP requests' do
        request_body = {
          jsonrpc: '2.0',
          id: 1,
          method: 'tools/list',
          params: {}
        }

        post '/mcp', request_body.to_json, 'CONTENT_TYPE' => 'application/json'
        expect(last_response.status).to be_between(200, 299)
      end
    end
  end

  describe '#start and #stop' do
    it 'starts the Puma server' do
      thread = Thread.new { http_server.start }
      sleep 0.5

      expect(http_server.instance_variable_get(:@puma_server)).not_to be_nil
      expect(http_server.instance_variable_get(:@puma_thread)).to be_alive

      http_server.stop
      thread.join(2)
    end
  end
end
