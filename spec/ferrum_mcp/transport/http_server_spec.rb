# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

RSpec.describe FerrumMCP::Transport::HTTPServer do
  include Rack::Test::Methods

  let(:config) { test_base_config }
  # Rack::Test's default host is example.org, which the SDK's DNS rebinding
  # protection rejects: MCP clients reach a local server through localhost.
  # The transport is stateful, so requests follow an initialize handshake.
  let(:mcp_session) { {} }
  let(:mcp_server) { FerrumMCP::Server.new(config) }
  let(:http_server) { described_class.new(mcp_server, config) }

  def app
    http_server.app
  end

  def mcp_post(body)
    header 'Host', 'localhost'
    header 'Accept', 'application/json, text/event-stream'
    header 'Mcp-Session-Id', mcp_session[:id] if mcp_session[:id]
    post '/mcp', body.to_json, 'CONTENT_TYPE' => 'application/json'
    mcp_session[:id] ||= last_response.headers['mcp-session-id']
    last_response
  end

  def mcp_initialize
    mcp_post(jsonrpc: '2.0', id: 1, method: 'initialize',
             params: { protocolVersion: '2025-03-26', capabilities: {}, clientInfo: { name: 'spec', version: '1' } })
  end

  def tools_list_request
    { jsonrpc: '2.0', id: 2, method: 'tools/list', params: {} }
  end

  def post_mcp_from(host, origin: nil)
    header 'Accept', 'application/json, text/event-stream'
    header 'Origin', origin if origin
    post '/mcp', tools_list_request.to_json, 'CONTENT_TYPE' => 'application/json', 'HTTP_HOST' => host
    last_response
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
      it 'answers the initialize handshake with a session id' do
        mcp_initialize

        expect(last_response.status).to eq(200)
        expect(mcp_session[:id]).not_to be_nil
      end

      it 'handles MCP requests within the session' do
        mcp_initialize
        mcp_post(tools_list_request)

        expect(last_response.status).to be_between(200, 299)
      end
    end
  end

  describe 'DNS rebinding protection' do
    it 'rejects a Host header that is neither loopback nor allow-listed (DNS rebinding)' do
      expect(post_mcp_from('evil.example').status).to eq(403)
    end

    it 'rejects a cross-origin browser request' do
      expect(post_mcp_from('localhost', origin: 'http://evil.example').status).to eq(403)
    end

    context 'with MCP_ALLOWED_HOSTS' do
      let(:config) do
        cfg = test_base_config
        cfg.mcp_allowed_hosts = ['mcp.example.com']
        cfg
      end

      it 'accepts the allow-listed host on any port' do
        expect(post_mcp_from('mcp.example.com:3000').status).not_to eq(403)
      end
    end

    context 'with MCP_ALLOWED_ORIGINS' do
      let(:config) do
        cfg = test_base_config
        cfg.mcp_allowed_origins = ['http://app.example.com']
        cfg
      end

      it 'accepts the allow-listed origin' do
        expect(post_mcp_from('localhost', origin: 'http://app.example.com').status).not_to eq(403)
      end
    end

    context 'with DNS_REBINDING_PROTECTION=false' do
      let(:config) do
        cfg = test_base_config
        cfg.dns_rebinding_protection = false
        cfg
      end

      it 'accepts any host' do
        expect(post_mcp_from('evil.example').status).not_to eq(403)
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

  describe 'API key authentication integration' do
    context 'when API key authentication is enabled' do
      let(:config) do
        cfg = test_base_config
        cfg.api_key_enabled = true
        cfg.api_keys = ['test-api-key']
        cfg
      end

      it 'requires authentication for /mcp endpoint' do
        mcp_initialize

        expect(last_response.status).to eq(401)
      end

      it 'allows authenticated requests to /mcp' do
        header 'Authorization', 'Bearer test-api-key'
        mcp_initialize
        mcp_post(tools_list_request)

        expect(last_response.status).to be_between(200, 299)
      end

      it 'allows unauthenticated access to /health' do
        get '/health'
        expect(last_response.status).to eq(200)
      end

      it 'allows unauthenticated access to root /' do
        get '/'
        expect(last_response.status).to eq(200)
      end

      # Rack routes "//mcp" to the /mcp endpoint; the root skip path must not
      # let such variants through unauthenticated.
      %w[//mcp ///mcp //mcp/].each do |path|
        it "requires authentication for #{path}" do
          # Rack::Test normalizes the URL, so hand the raw path to the app
          body = { jsonrpc: '2.0', id: 1, method: 'tools/list' }.to_json
          env = Rack::MockRequest.env_for('/mcp', method: 'POST', input: body, 'CONTENT_TYPE' => 'application/json')
          env['PATH_INFO'] = path
          status, = app.call(env)

          expect(status).to eq(401)
        end
      end
    end

    context 'when API key authentication is disabled' do
      let(:config) do
        cfg = test_base_config
        cfg.api_key_enabled = false
        cfg
      end

      it 'allows unauthenticated access to /mcp' do
        mcp_initialize
        mcp_post(tools_list_request)

        expect(last_response.status).to be_between(200, 299)
      end
    end
  end

  describe 'proxy trust' do
    it 'defaults TRUST_PROXY to false' do
      expect(config.trust_proxy).to be(false)
    end

    it 'reads TRUST_PROXY from the environment' do
      ENV['TRUST_PROXY'] = 'true'
      expect(FerrumMCP::Configuration.new.trust_proxy).to be(true)
    ensure
      ENV.delete('TRUST_PROXY')
    end

    it 'passes trust_proxy to the rate limiter' do
      allow(FerrumMCP::Transport::RateLimiter).to receive(:new).and_call_original
      config.rate_limit_enabled = true
      config.trust_proxy = true

      app

      expect(FerrumMCP::Transport::RateLimiter).to have_received(:new)
        .with(anything, hash_including(trust_proxy: true))
    end
  end
end
