# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FerrumMCP::UrlPolicy do
  it 'allows everything when nothing is configured' do
    policy = described_class.new

    expect(policy.restricted?).to be(false)
    expect(policy.allowed?('http://169.254.169.254/latest')).to be(true)
  end

  # rubocop:disable RSpec/MultipleExpectations
  it 'blocks exact hosts, wildcard suffixes and CIDR ranges' do
    policy = described_class.new(blocked: ['localhost', '*.internal', '169.254.0.0/16', '10.0.0.0/8'])

    expect(policy.allowed?('http://localhost:3000/')).to be(false)
    expect(policy.allowed?('https://db.internal/')).to be(false)
    expect(policy.allowed?('https://internal/')).to be(false)
    expect(policy.allowed?('http://169.254.169.254/')).to be(false)
    expect(policy.allowed?('http://10.1.2.3/')).to be(false)
    expect(policy.allowed?('https://example.com/')).to be(true)
  end
  # rubocop:enable RSpec/MultipleExpectations

  it 'only allows listed hosts when an allow list is set, block list winning' do
    policy = described_class.new(allowed: ['*.example.com'], blocked: ['admin.example.com'])

    expect(policy.allowed?('https://www.example.com/')).to be(true)
    expect(policy.allowed?('https://example.com/')).to be(true)
    expect(policy.allowed?('https://admin.example.com/')).to be(false)
    expect(policy.allowed?('https://other.org/')).to be(false)
  end

  it 'raises a descriptive error from check!' do
    policy = described_class.new(blocked: ['localhost'])

    expect { policy.check!('http://localhost/') }
      .to raise_error(described_class::BlockedURLError, /localhost/)
    expect { policy.check!('https://example.com/') }.not_to raise_error
  end

  it 'is built from ALLOWED_HOSTS / BLOCKED_HOSTS' do
    ENV['BLOCKED_HOSTS'] = 'localhost, 127.0.0.0/8'

    policy = FerrumMCP::Configuration.new.url_policy

    expect(policy.allowed?('http://127.0.0.1:9999/')).to be(false)
    expect(policy.allowed?('https://example.com/')).to be(true)
  end

  describe 'navigate tool enforcement' do
    let(:session_manager) { FerrumMCP::SessionManager.new(FerrumMCP::Configuration.new) }

    after { session_manager.shutdown }

    it 'refuses navigation to a blocked host without touching the browser' do
      ENV['BLOCKED_HOSTS'] = 'localhost'
      sid = session_manager.create_session(headless: true)

      result = session_manager.with_session(sid) do |bm|
        allow(bm.page).to receive(:goto)
        FerrumMCP::Tools::NavigateTool.new(bm).execute(session_id: sid, url: test_url('/test'))
      end

      expect(result[:success]).to be false
      expect(result[:error]).to include('not allowed')
    end
  end
end
