# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

RSpec.describe FerrumMCP::Transport::ApiKeyAuthenticator do
  include Rack::Test::Methods

  let(:inner_app) do
    ->(_env) { [200, { 'Content-Type' => 'application/json' }, ['{"status":"ok"}']] }
  end
  let(:api_keys) { %w[test-api-key-123 another-key-456] }
  let(:logger) { instance_double(Logger, warn: nil) }
  let(:skip_paths) { ['/health'] }

  let(:middleware) do
    described_class.new(inner_app,
                        api_keys: api_keys,
                        logger: logger,
                        skip_paths: skip_paths)
  end

  def app
    middleware
  end

  describe 'authentication' do
    context 'with valid Bearer token' do
      it 'allows access with correct API key' do
        header 'Authorization', 'Bearer test-api-key-123'
        get '/mcp'

        expect(last_response.status).to eq(200)
        expect(JSON.parse(last_response.body)).to eq({ 'status' => 'ok' })
      end

      it 'allows access with any valid API key from the list' do
        header 'Authorization', 'Bearer another-key-456'
        get '/mcp'

        expect(last_response.status).to eq(200)
      end
    end

    context 'with invalid Bearer token' do
      it 'returns 401 for wrong API key' do
        header 'Authorization', 'Bearer wrong-api-key'
        get '/mcp'

        expect(last_response.status).to eq(401)
        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('Unauthorized')
        expect(body['message']).to eq('Invalid API key')
      end

      it 'returns 401 for empty Bearer token' do
        header 'Authorization', 'Bearer '
        get '/mcp'

        expect(last_response.status).to eq(401)
      end
    end

    context 'without Authorization header' do
      it 'returns 401 when header is missing' do
        get '/mcp'

        expect(last_response.status).to eq(401)
        body = JSON.parse(last_response.body)
        expect(body['error']).to eq('Unauthorized')
        expect(body['message']).to eq('Missing Authorization header')
      end
    end

    context 'with non-Bearer Authorization header' do
      it 'returns 401 for Basic auth header' do
        header 'Authorization', 'Basic dXNlcjpwYXNz'
        get '/mcp'

        expect(last_response.status).to eq(401)
        body = JSON.parse(last_response.body)
        expect(body['message']).to eq('Missing Authorization header')
      end
    end
  end

  describe 'skip paths' do
    it 'allows access to /health without authentication' do
      get '/health'

      expect(last_response.status).to eq(200)
    end

    it 'allows access to nested paths under skip path' do
      middleware_with_skip = described_class.new(inner_app,
                                                 api_keys: api_keys,
                                                 skip_paths: ['/public'])
      app_with_skip = middleware_with_skip

      env = Rack::MockRequest.env_for('/public/assets/image.png')
      status, _headers, _body = app_with_skip.call(env)

      expect(status).to eq(200)
    end

    it 'requires authentication for non-skip paths' do
      get '/mcp'

      expect(last_response.status).to eq(401)
    end
  end

  describe 'response headers' do
    it 'includes WWW-Authenticate header on 401' do
      get '/mcp'

      expect(last_response.status).to eq(401)
      expect(last_response.headers['WWW-Authenticate']).to eq('Bearer realm="ferrum-mcp"')
    end

    it 'returns JSON content type on 401' do
      get '/mcp'

      expect(last_response.content_type).to include('application/json')
    end
  end

  describe 'logging' do
    it 'logs authentication failures without exposing credentials' do
      header 'Authorization', 'Bearer invalid-key'
      get '/mcp'

      expect(logger).to have_received(:warn).with(/Authentication failed: Invalid API key/)
    end

    it 'includes IP address in log message' do
      header 'Authorization', 'Bearer invalid-key'
      get '/mcp'

      expect(logger).to have_received(:warn).with(/IP:/)
    end

    it 'does not log the attempted API key' do
      header 'Authorization', 'Bearer secret-key-should-not-appear'
      get '/mcp'

      expect(logger).to have_received(:warn) do |message|
        expect(message).not_to include('secret-key-should-not-appear')
      end
    end
  end

  describe 'security' do
    context 'with timing attack prevention' do
      it 'uses constant-time comparison for keys' do
        # This is a behavioral test - we verify the method exists and is used
        authenticator = described_class.new(inner_app, api_keys: ['key'])

        # Access private method for testing
        expect(authenticator.send(:secure_compare, 'abc', 'abc')).to be true
        expect(authenticator.send(:secure_compare, 'abc', 'abd')).to be false
        expect(authenticator.send(:secure_compare, 'abc', 'ab')).to be false
        expect(authenticator.send(:secure_compare, nil, 'abc')).to be false
        expect(authenticator.send(:secure_compare, 'abc', nil)).to be false
      end
    end

    context 'with no API keys configured' do
      let(:middleware_no_keys) do
        described_class.new(inner_app, api_keys: [], skip_paths: skip_paths)
      end

      it 'rejects all requests when no keys are configured' do
        env = Rack::MockRequest.env_for('/mcp', 'HTTP_AUTHORIZATION' => 'Bearer any-key')
        status, _headers, body = middleware_no_keys.call(env)

        expect(status).to eq(401)
        parsed_body = JSON.parse(body.first)
        expect(parsed_body['message']).to eq('Invalid API key')
      end
    end
  end

  describe 'X-Forwarded-For handling' do
    it 'logs the first IP from X-Forwarded-For header' do
      header 'Authorization', 'Bearer invalid-key'
      header 'X-Forwarded-For', '203.0.113.1, 198.51.100.1'
      get '/mcp'

      expect(logger).to have_received(:warn).with(/IP: 203.0.113.1/)
    end
  end
end
