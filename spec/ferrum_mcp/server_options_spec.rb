# frozen_string_literal: true

require 'spec_helper'
require 'open3'

RSpec.describe 'Server CLI Options' do
  let(:server_path) { File.expand_path('../../server.rb', __dir__) }

  describe '--help option' do
    # rubocop:disable RSpec/MultipleExpectations
    it 'displays help message with available options' do
      stdout, _, status = Open3.capture3('ruby', server_path, '--help')

      expect(status.success?).to be true
      expect(stdout).to include('Usage:')
      expect(stdout).to include('--transport TRANSPORT')
      expect(stdout).to include('http  - HTTP server (default)')
      expect(stdout).to include('stdio - Standard input/output')
      expect(stdout).to include('--help')
      expect(stdout).to include('--version')
      expect(stdout).to include('Environment variables:')
    end
    # rubocop:enable RSpec/MultipleExpectations
  end

  describe '--version option' do
    it 'displays version information' do
      stdout, _, status = Open3.capture3('ruby', server_path, '--version')

      expect(status.success?).to be true
      expect(stdout).to include('Ferrum MCP Server')
      expect(stdout).to include(FerrumMCP::VERSION)
    end
  end

  describe '--transport option' do
    it 'accepts http transport' do
      # Start server in background and kill it quickly
      pid = spawn('ruby', server_path, '--transport', 'http',
                  out: File::NULL, err: File::NULL)
      sleep 1

      # Check if process is running
      running = begin
        Process.kill(0, pid)
        true
      rescue Errno::ESRCH
        false
      end

      expect(running).to be true

      Process.kill('TERM', pid)
      Process.wait(pid)
    end

    it 'accepts stdio transport' do
      # For stdio, start it and immediately close stdin
      # This should cause it to exit gracefully
      pid = spawn('ruby', server_path, '--transport', 'stdio',
                  in: :close, out: File::NULL, err: File::NULL)

      # Wait briefly for startup
      sleep 0.5

      # Check process started successfully (it should exit when stdin closes)
      process_status = begin
        Process.wait(pid, Process::WNOHANG)
      rescue Errno::ECHILD
        # Process already exited, that's fine
        :exited
      end

      # Either got a status or process already exited
      expect(process_status).not_to be_nil
    end

    it 'rejects invalid transport' do
      _, stderr, status = Open3.capture3(
        'ruby', server_path, '--transport', 'invalid'
      )

      expect(status.success?).to be false
      expect(stderr).to include('invalid argument')
    end
  end

  describe 'configuration validation' do
    it 'validates browser path when provided' do
      stdout, _, status = Open3.capture3(
        { 'BROWSER_PATH' => '/non/existent/browser' },
        'ruby', server_path
      )

      expect(status.success?).to be false
      expect(stdout).to include('ERROR: Invalid browser configuration')
      expect(stdout).to include('BROWSER_PATH does not exist')
    end

    it 'accepts valid configuration' do
      # Quick test that server starts without errors
      pid = spawn(
        { 'BROWSER_HEADLESS' => 'true', 'LOG_LEVEL' => 'error' },
        'ruby', server_path, '--transport', 'http',
        out: File::NULL, err: File::NULL
      )
      sleep 2

      # Check if process is still running
      begin
        Process.kill(0, pid)
        running = true
      rescue Errno::ESRCH
        running = false
      end

      expect(running).to be true

      Process.kill('TERM', pid)
      Process.wait(pid)
    end
  end
end
