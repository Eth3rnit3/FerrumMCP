# frozen_string_literal: true

require 'spec_helper'
require 'open3'

RSpec.describe 'Server CLI Options' do
  let(:server_path) { File.expand_path('../../bin/ferrum-mcp', __dir__) }

  describe '--help option' do
    # rubocop:disable RSpec/MultipleExpectations
    it 'displays help message with available options' do
      stdout, _, status = Open3.capture3('ruby', server_path, 'help')

      expect(status.success?).to be true
      expect(stdout).to include('USAGE:')
      expect(stdout).to include('--transport TYPE')
      expect(stdout).to include('Transport type: http or stdio')
      expect(stdout).to include('--help')
      expect(stdout).to include('--version')
      expect(stdout).to include('ENVIRONMENT VARIABLES:')
    end
    # rubocop:enable RSpec/MultipleExpectations
  end

  describe '--version option' do
    it 'displays version information' do
      stdout, _, status = Open3.capture3('ruby', server_path, 'version')

      expect(status.success?).to be true
      expect(stdout).to include('FerrumMCP')
      expect(stdout).to include(FerrumMCP::VERSION)
    end
  end

  describe '--transport option' do
    it 'accepts http transport' do
      # Start server in background and kill it quickly
      pid = spawn('ruby', server_path, 'start', '--transport', 'http',
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
      pid = spawn('ruby', server_path, 'start', '--transport', 'stdio',
                  in: :close, out: File::NULL, err: File::NULL)

      # Wait for process to exit (with timeout to prevent hanging)
      # The process should exit quickly when stdin is closed
      process_status = nil
      timeout = 5 # seconds
      start_time = Time.now

      loop do
        process_status = begin
          Process.wait(pid, Process::WNOHANG)
        rescue Errno::ECHILD
          # Process already exited, that's fine
          :exited
        end

        break if process_status # Process finished

        if Time.now - start_time > timeout
          # Timeout - kill the process
          begin
            Process.kill('TERM', pid)
          rescue StandardError
            nil
          end
          begin
            Process.wait(pid)
          rescue StandardError
            nil
          end
          break
        end

        sleep 0.1 # Check every 100ms
      end

      # Either got a status or process already exited
      expect(process_status).not_to be_nil
    end

    it 'rejects invalid transport' do
      _, stderr, status = Open3.capture3(
        'ruby', server_path, 'start', '--transport', 'invalid'
      )

      expect(status.success?).to be false
      expect(stderr).to include('invalid argument')
    end
  end

  describe 'configuration validation' do
    it 'validates browser path when provided' do
      stdout, _, status = Open3.capture3(
        { 'BROWSER_PATH' => '/non/existent/browser' },
        'ruby', server_path, 'start'
      )

      expect(status.success?).to be false
      expect(stdout).to include('ERROR: Invalid browser configuration')
      expect(stdout).to include('BROWSER_PATH does not exist')
    end

    it 'accepts valid configuration' do
      # Quick test that server starts without errors
      pid = spawn(
        { 'BROWSER_HEADLESS' => 'true', 'LOG_LEVEL' => 'error' },
        'ruby', server_path, 'start', '--transport', 'http',
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
