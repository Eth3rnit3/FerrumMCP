# frozen_string_literal: true

require 'bundler/setup'
require 'ferrum_mcp'
require 'webrick'
require 'rack'

# Set environment variables for tests
ENV['BROWSER_HEADLESS'] = 'true'
ENV['LOG_LEVEL'] = 'error'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Start a test HTTP server for testing
  config.before(:suite) do
    @test_server = start_test_server
  end

  config.after(:suite) do
    @test_server&.shutdown
  end
end

def start_test_server
  port = 9999

  server = WEBrick::HTTPServer.new(
    Port: port,
    Logger: WEBrick::Log.new(File::NULL),
    AccessLog: []
  )

  server.mount_proc '/test' do |_req, res|
    res.status = 200
    res['Content-Type'] = 'text/html'
    res.body = <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>Test Page</title></head>
      <body>
        <h1 id="title">Test Page</h1>
        <p id="content">This is a test page for browser automation.</p>
        <form id="test-form">
          <input type="text" id="name-input" name="name" placeholder="Enter name">
          <input type="email" id="email-input" name="email" placeholder="Enter email">
          <button type="submit" id="submit-btn">Submit</button>
        </form>
        <div id="hidden" style="display:none;">Hidden content</div>
        <a href="/test/page2" id="link">Go to Page 2</a>
      </body>
      </html>
    HTML
  end

  server.mount_proc '/test/page2' do |_req, res|
    res.status = 200
    res['Content-Type'] = 'text/html'
    res.body = <<~HTML
      <!DOCTYPE html>
      <html>
      <head><title>Page 2</title></head>
      <body>
        <h1>Page 2</h1>
        <p>This is page 2</p>
      </body>
      </html>
    HTML
  end

  Thread.new { server.start }

  # Wait for server to be ready
  sleep 1

  server
end

def test_url(path = '/test')
  "http://localhost:9999#{path}"
end

def test_config
  config = FerrumMCP::Configuration.new
  config.headless = true
  config.log_level = :error
  config
end
