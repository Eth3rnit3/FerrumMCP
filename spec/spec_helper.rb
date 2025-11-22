# frozen_string_literal: true

# SimpleCov for code coverage
if ENV['COVERAGE'] || ENV['CI']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec/'
    add_filter '/vendor/'
    add_filter '/scripts/'
    add_filter '/test/'
    enable_coverage :branch
    minimum_coverage 50
  end
end

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

  # Clean up browser/profile environment variables before each spec
  # to ensure consistent test environment
  config.before do
    preserved_keys = %w[BROWSER_HEADLESS BROWSER_TIMEOUT LOG_LEVEL COVERAGE CI]
    ENV.keys.grep(/^(BROWSER_|USER_PROFILE_|BOT_PROFILE_|BOTBROWSER_)/).each do |key|
      ENV.delete(key) unless preserved_keys.include?(key)
    end
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

  # Mount all HTML fixtures automatically
  fixtures_dir = File.join(File.dirname(__FILE__), 'fixtures', 'pages')

  if Dir.exist?(fixtures_dir)
    mount_fixtures(server, fixtures_dir, '/fixtures')
  end

  # Keep the default test page for backward compatibility
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
        <form id="test-form" onsubmit="return false;">
          <input type="text" id="name-input" name="name" placeholder="Enter name">
          <input type="email" id="email-input" name="email" placeholder="Enter email">
          <input type="search" id="search-input" name="search" placeholder="Search">
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

# Recursively mount all HTML fixtures from a directory
def mount_fixtures(server, dir, url_prefix)
  Dir.glob(File.join(dir, '**', '*.html')).each do |file_path|
    # Calculate the URL path relative to fixtures/pages
    relative_path = file_path.sub(dir, '').sub(/\.html$/, '')
    url_path = File.join(url_prefix, relative_path)

    # Read the HTML content
    html_content = File.read(file_path)

    # Mount the fixture
    server.mount_proc url_path do |_req, res|
      res.status = 200
      res['Content-Type'] = 'text/html'
      res.body = html_content
    end

    puts "Mounted fixture: #{url_path} -> #{file_path}" if ENV['DEBUG_FIXTURES']
  end
end

def test_url(path = '/test')
  "http://localhost:9999#{path}"
end

def test_base_config
  FerrumMCP::Configuration.new
end

def test_config
  # Create a SessionConfiguration for BrowserManager tests
  # This wraps the base configuration with session-specific overrides
  base_config = test_base_config
  session = FerrumMCP::Session.new(config: base_config, options: { headless: true })
  session.session_config
end

# Session test helpers for tool tests
module SessionTestHelpers
  # Create a session and navigate to a fixture file via test server
  # @param session_manager [FerrumMCP::SessionManager] The session manager instance
  # @param fixture_file [String] Fixture filename (e.g., 'banner_with_id.html')
  # @param subdir [String] Optional subdirectory within pages/ (e.g., 'cookies')
  # @return [String] The session ID
  def setup_session_with_fixture(session_manager, fixture_file, subdir: nil)
    session_params = {
      headless: true,
      timeout: 30,
      browser_options: {}
    }
    # create_session returns the session_id directly (string)
    sid = session_manager.create_session(session_params)

    # Build URL path for mounted fixture
    # Remove .html extension as it's removed during mounting
    fixture_name = fixture_file.sub(/\.html$/, '')
    url_path = if subdir
                 "/fixtures/#{subdir}/#{fixture_name}"
               else
                 "/fixtures/#{fixture_name}"
               end

    session_manager.with_session(sid) do |browser_manager|
      browser_manager.browser.goto(test_url(url_path))
      sleep 0.5 # Give time for page to load
    end

    sid
  end

  # Check if a specific element exists in the page
  # @param session_manager [FerrumMCP::SessionManager] The session manager instance
  # @param session_id [String] The session ID
  # @param selector [String] CSS selector
  # @return [Boolean] true if element exists
  def element_exists?(session_manager, session_id, selector)
    session_manager.with_session(session_id) do |browser_manager|
      element = browser_manager.browser.at_css(selector)
      return !element.nil?
    end
  rescue StandardError
    false
  end

  # Get element text content
  # @param session_manager [FerrumMCP::SessionManager] The session manager instance
  # @param session_id [String] The session ID
  # @param selector [String] CSS selector
  # @return [String, nil] Element text or nil if not found
  def get_element_text(session_manager, session_id, selector)
    session_manager.with_session(session_id) do |browser_manager|
      element = browser_manager.browser.at_css(selector)
      return element&.text
    end
  rescue StandardError
    nil
  end

  # Execute JavaScript in the browser context
  # @param session_manager [FerrumMCP::SessionManager] The session manager instance
  # @param session_id [String] The session ID
  # @param script [String] JavaScript code to execute
  # @return [Object] Result of JavaScript execution
  def execute_js(session_manager, session_id, script)
    session_manager.with_session(session_id) do |browser_manager|
      browser_manager.browser.execute(script)
    end
  rescue StandardError => e
    raise "JavaScript execution failed: #{e.message}"
  end
end

RSpec.configure do |config|
  config.include SessionTestHelpers
end
