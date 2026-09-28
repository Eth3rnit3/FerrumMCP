# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

RSpec.describe FerrumMCP::Transport::RateLimiter do
  include Rack::Test::Methods

  let(:inner_app) { ->(_env) { [200, { 'Content-Type' => 'text/plain' }, ['ok']] } }
  let(:options) { { max_requests: 2, window: 60 } }
  let(:middleware) { described_class.new(inner_app, options) }

  def app
    middleware
  end

  it 'allows requests under the limit and rejects the ones above' do
    2.times { get '/mcp' }
    expect(last_response.status).to eq(200)

    get '/mcp'
    expect(last_response.status).to eq(429)
    expect(last_response.headers['Retry-After']).to eq('60')
  end

  it 'ignores X-Forwarded-For by default so a client cannot spoof its identity' do
    3.times do |i|
      header 'X-Forwarded-For', "10.0.0.#{i}"
      get '/mcp'
    end

    expect(last_response.status).to eq(429)
  end

  context 'when trust_proxy is enabled' do
    let(:options) { { max_requests: 2, window: 60, trust_proxy: true } }

    it 'rate limits per forwarded client address' do
      3.times do |i|
        header 'X-Forwarded-For', "10.0.0.#{i}"
        get '/mcp'
      end

      expect(last_response.status).to eq(200)
    end
  end
end
