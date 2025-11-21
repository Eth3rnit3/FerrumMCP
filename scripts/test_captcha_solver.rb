#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for CAPTCHA solving
# Usage: ruby scripts/test_captcha_solver.rb <url>
# Example: ruby scripts/test_captcha_solver.rb https://www.google.com/recaptcha/api2/demo

require 'bundler/setup'
require_relative '../lib/ferrum_mcp'

require 'fileutils'
require 'json'
require 'base64'

ENV["BROWSER_PATH"] ||= '/Applications/Chromium.app/Contents/MacOS/Chromium'
ENV["BOTBROWSER_PROFILE"] ||= '/Users/eth3rnit3/Downloads/chrome142_win10_x64.enc'

# Create output directory for screenshots
OUTPUT_DIR = 'tmp/captcha_tests'
FileUtils.mkdir_p(OUTPUT_DIR)

class CaptchaSolverTester
  attr_reader :url, :test_name

  def initialize(url)
    @url = url
    @test_name = sanitize_filename(url)
    @session = nil
  end

  def run
    puts '=' * 80
    puts "Testing CAPTCHA solver on: #{url}"
    puts '=' * 80
    puts

    create_session
    navigate_to_page
    take_before_screenshot
    solve_captcha
    take_after_screenshot
    analyze_results
  ensure
    close_session
  end

  private

  def create_session
    puts '[1/6] Creating browser session...'
    config = FerrumMCP::Configuration.new

    browser_options = {
      'window-size' => '1920,1080',
      'disable-blink-features' => 'AutomationControlled',
      'disable-dev-shm-usage' => nil,
      'no-sandbox' => nil,
      'disable-setuid-sandbox' => nil,
      'disable-infobars' => nil,
      'disable-web-security' => nil,
      'disable-features' => 'IsolateOrigins,site-per-process'
    }

    @session = FerrumMCP::Session.new(
      config: config,
      options: {
        headless: false, # Set to false to see what's happening
        timeout: 90,     # Longer timeout for CAPTCHA solving
        browser_options:
      }
    )

    puts "  ✓ Session created: #{@session.id}"
    puts
  end

  def navigate_to_page
    puts "[2/6] Navigating to #{url}..."
    @session.start # Start the browser

    # Inject anti-detection scripts before navigation
    inject_stealth_scripts

    tool = FerrumMCP::Tools::NavigateTool.new(@session.browser_manager)
    result = tool.execute({ url: url })

    unless result[:success]
      puts "  ✗ Navigation failed: #{result[:error]}"
      exit 1
    end

    puts '  ✓ Page loaded successfully'
    puts "  Title: #{result[:data][:title] || 'N/A'}"

    # Wait a bit for CAPTCHA to appear
    puts '  ⏳ Waiting 2 seconds for CAPTCHA to load...'
    sleep 2
    puts
  end

  def inject_stealth_scripts
    browser = @session.browser_manager.browser

    # Hide webdriver property
    browser.execute(<<~JAVASCRIPT)
      Object.defineProperty(navigator, 'webdriver', {
        get: () => undefined
      });
    JAVASCRIPT

    # Override plugins and languages
    browser.execute(<<~JAVASCRIPT)
      Object.defineProperty(navigator, 'plugins', {
        get: () => [1, 2, 3, 4, 5]
      });
      Object.defineProperty(navigator, 'languages', {
        get: () => ['fr-FR', 'fr', 'en-US', 'en']
      });
    JAVASCRIPT
  rescue StandardError => e
    puts "  ⚠ Warning: Could not inject stealth scripts: #{e.message}"
  end

  def take_before_screenshot
    puts "[3/6] Taking 'before' screenshot..."
    screenshot_path = File.join(OUTPUT_DIR, "#{test_name}_before.png")

    tool = FerrumMCP::Tools::ScreenshotTool.new(@session.browser_manager)
    result = tool.execute({ full_page: false })

    unless result[:success]
      puts "  ✗ Screenshot failed: #{result[:error]}"
      return
    end

    # Save the base64 image
    image_data = result[:data]
    File.write(screenshot_path, Base64.decode64(image_data))

    puts "  ✓ Screenshot saved: #{screenshot_path}"
    puts
  end

  def solve_captcha
    puts '[4/6] Attempting to solve CAPTCHA...'
    puts '  Detection strategies:'
    puts '    1. Known CAPTCHA frameworks (reCAPTCHA, hCaptcha)'
    puts '    2. Iframe detection'
    puts '    3. Text-based detection'
    puts
    puts '  Solving steps:'
    puts '    1. Detect and click audio button'
    puts '    2. Download audio challenge'
    puts '    3. Transcribe with Whisper'
    puts '    4. Fill answer and submit'
    puts

    tool = FerrumMCP::Tools::SolveCaptchaTool.new(@session.browser_manager)
    @solve_result = tool.execute({})

    if @solve_result[:success]
      result_data = @solve_result[:data]
      puts '  ✓ Success!'
      puts "  Transcription: #{result_data[:transcription]}"
      puts "  Audio button: #{result_data[:audio_button]}"
      puts "  Input field: #{result_data[:input_field]}"
      puts "  Verify button: #{result_data[:verify_button]}"
      @solving_success = true
      @transcription = result_data[:transcription]
      @audio_button = result_data[:audio_button]
    else
      puts "  ✗ Failed: #{@solve_result[:error]}"
      @solving_success = false
    end

    # Wait for any verification animations
    sleep 3
    puts
  end

  def take_after_screenshot
    puts "[5/6] Taking 'after' screenshot..."
    screenshot_path = File.join(OUTPUT_DIR, "#{test_name}_after.png")

    tool = FerrumMCP::Tools::ScreenshotTool.new(@session.browser_manager)
    result = tool.execute({ full_page: false })

    unless result[:success]
      puts "  ✗ Screenshot failed: #{result[:error]}"
      return
    end

    # Save the base64 image
    image_data = result[:data]
    File.write(screenshot_path, Base64.decode64(image_data))

    puts "  ✓ Screenshot saved: #{screenshot_path}"
    puts
  end

  def analyze_results
    puts '[6/6] Analysis'
    puts '=' * 80

    if @solving_success
      puts '✓ CAPTCHA solving: SUCCESS'
      puts "  Transcription: #{@transcription}"
      puts "  Audio button detected: #{@audio_button}"
      puts
      puts 'Next steps:'
      puts "  1. Open the screenshots in #{OUTPUT_DIR}/"
      puts '  2. Compare before/after to verify the CAPTCHA was actually solved'
      puts '  3. Check if the page progressed after solving'
      puts
      puts 'Whisper configuration:'
      puts "  WHISPER_PATH: #{ENV.fetch('WHISPER_PATH', 'whisper-cli (default)')}"
      puts "  WHISPER_MODEL: #{ENV.fetch('WHISPER_MODEL', 'base (default)')}"
      puts "  WHISPER_LANGUAGE: #{ENV.fetch('WHISPER_LANGUAGE', 'en (default)')}"
    else
      puts '✗ CAPTCHA solving: FAILED'
      puts "  Error: #{@solve_result[:error]}"
      puts
      puts 'Possible reasons:'
      puts '  1. No CAPTCHA on this page'
      puts '  2. Whisper CLI not installed (macOS: brew install whisper-cpp)'
      puts '  3. CAPTCHA type not supported (only audio challenges)'
      puts '  4. CAPTCHA framework not recognized'
      puts '  5. Model not downloaded (will auto-download on first run)'
      puts
      puts 'Manual investigation:'
      puts "  Check the 'before' screenshot to see if a CAPTCHA is visible"
      puts '  Check logs in logs/ferrum_mcp.log for detailed error messages'
    end

    puts
    puts 'Screenshots saved:'
    puts "  Before: #{OUTPUT_DIR}/#{test_name}_before.png"
    puts "  After:  #{OUTPUT_DIR}/#{test_name}_after.png"
    puts '=' * 80
  end

  def close_session
    return unless @session

    puts
    puts 'Closing session in 5 seconds...'
    puts '(Press Ctrl+C to keep browser open for inspection)'
    sleep 5
    @session.stop
    puts 'Session closed.'
  rescue Interrupt
    puts
    puts 'Interrupted. Browser will remain open.'
    puts 'Remember to close it manually!'
  end

  def sanitize_filename(url)
    # Extract domain from URL and make it filename-safe
    domain = url.gsub(%r{https?://}, '').tr('/', '_').gsub(/[^\w\-.]/, '_')
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    "#{domain}_#{timestamp}"
  end
end

# Main execution
if ARGV.empty?
  puts 'Usage: ruby scripts/test_captcha_solver.rb <url>'
  puts
  puts 'Examples:'
  puts '  ruby scripts/test_captcha_solver.rb https://www.google.com/recaptcha/api2/demo'
  puts '  ruby scripts/test_captcha_solver.rb https://www.hcaptcha.com/demo'
  puts
  puts 'Prerequisites:'
  puts '  1. Install Whisper CLI:'
  puts '     macOS: brew install whisper-cpp'
  puts '     Linux: https://github.com/ggerganov/whisper.cpp'
  puts '  2. (Optional) Set WHISPER_PATH if not in PATH (default: whisper-cli)'
  puts '  3. (Optional) Set WHISPER_MODEL (default: base, options: tiny/base/small/medium)'
  puts '  4. (Optional) Set WHISPER_LANGUAGE (default: en)'
  puts
  exit 1
end

url = ARGV[0]

# Validate URL
unless url.match?(%r{^https?://})
  puts 'Error: URL must start with http:// or https://'
  exit 1
end

# Check if Whisper is available
puts 'Checking Whisper availability...'
whisper_path = ENV.fetch('WHISPER_PATH', 'whisper-cli')
stdout, stderr, status = Open3.capture3("#{whisper_path} --help 2>&1")

unless status.success?
  puts '✗ Whisper CLI not found!'
  puts
  puts 'Please install Whisper CLI:'
  puts '  macOS: brew install whisper-cpp'
  puts '  Linux: https://github.com/ggerganov/whisper.cpp'
  puts
  puts 'Or set WHISPER_PATH environment variable:'
  puts '  export WHISPER_PATH=/path/to/whisper-cli'
  puts
  puts "Error: #{stderr}"
  exit 1
end

puts "✓ Whisper CLI found: #{whisper_path}"
puts

# Run the test
tester = CaptchaSolverTester.new(url)
tester.run
