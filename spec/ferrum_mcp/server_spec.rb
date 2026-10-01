# frozen_string_literal: true

require 'spec_helper'
require 'stringio'

RSpec.describe FerrumMCP::Server do
  let(:log_output) { StringIO.new }
  let(:config) { FerrumMCP::Configuration.new }
  let(:logger) { Logger.new(log_output, level: :debug) }
  let(:server) { described_class.new(config) }

  before { allow(config).to receive(:logger).and_return(logger) }

  after { server.shutdown }

  it 'logs tool execution without dumping arbitrary tool arguments' do
    params = { metadata: { password: 'private-password', cookie: 'private-cookie', token: 'private-token' } }

    server.send(:execute_tool, FerrumMCP::Tools::CreateSessionTool, params)

    expect(log_output.string).to include('Executing tool: create_session')
    expect(log_output.string).not_to include('private-password', 'private-cookie', 'private-token')
  end

  it 'reports an exception without dumping its request context' do
    error = StandardError.new('Test failure')
    error.set_backtrace(['example.rb:1'])

    server.send(:report_exception, error, { params: { password: 'private-context-password' } })

    expect(log_output.string).to include('Test failure', 'example.rb:1')
    expect(log_output.string).not_to include('private-context-password')
  end
end
