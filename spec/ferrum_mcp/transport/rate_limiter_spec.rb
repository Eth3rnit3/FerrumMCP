# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'timeout'

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

  it 'admits only one simultaneous request when the quota is one' do
    limiter = described_class.new(inner_app, max_requests: 1, window: 60)
    arrived = Queue.new
    release = Queue.new
    # Pause each thread after its first critical section. A separate quota
    # check and increment would let both checks succeed before either counts.
    mutex = limiter.instance_variable_get(:@mutex)
    mutex.define_singleton_method(:synchronize) do |&block|
      result = super(&block)
      unless Thread.current.thread_variable_get(:rate_limiter_checked)
        Thread.current.thread_variable_set(:rate_limiter_checked, true)
        arrived << true
        release.pop
      end
      result
    end

    threads = Array.new(2) { Thread.new { limiter.call('REMOTE_ADDR' => '127.0.0.1').first } }
    Timeout.timeout(5) { 2.times { arrived.pop } }
    2.times { release << true }

    expect(threads.map(&:value).sort).to eq([200, 429])
  ensure
    2.times { release << true }
    threads&.each { |thread| thread.join(5) || thread.kill }
  end

  it 'allows requests again after the window expires' do
    now = Time.now
    allow(Time).to receive(:now).and_return(now)
    3.times { get '/mcp' }
    expect(last_response.status).to eq(429)

    allow(Time).to receive(:now).and_return(now + options[:window])
    get '/mcp'
    expect(last_response.status).to eq(200)
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
