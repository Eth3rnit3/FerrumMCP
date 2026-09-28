#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for cookie banner acceptance
# Usage: ruby test_cookie_banner.rb <url>
# Example: ruby test_cookie_banner.rb https://www.lemonde.fr

require 'bundler/setup'
require_relative 'lib/ferrum_mcp'

require 'fileutils'
require 'json'
require 'base64'

# Create output directory for screenshots
OUTPUT_DIR = 'tmp/cookie_tests'
FileUtils.mkdir_p(OUTPUT_DIR)

class CookieBannerTester
  attr_reader :url, :test_name

  def initialize(url)
    @url = url
    @test_name = sanitize_filename(url)
    @session = nil
  end

  def run
    puts '=' * 80
    puts "Testing cookie banner acceptance on: #{url}"
    puts '=' * 80
    puts

    create_session
    navigate_to_page
    take_before_screenshot
    accept_cookies
    take_after_screenshot
    analyze_results
  ensure
    close_session
  end

  private

  def create_session
    puts '[1/6] Creating browser session...'
    config = FerrumMCP::Configuration.new

    @session = FerrumMCP::Session.new(
      config: config,
      options: {
        headless: false, # Set to false to see what's happening
        timeout: 60,
        browser_options: {
          'window-size' => '1920,1080',
          'disable-blink-features' => 'AutomationControlled'
        }
      }
    )

    puts "  ✓ Session created: #{@session.id}"
    puts
  end

  def navigate_to_page
    puts "[2/6] Navigating to #{url}..."
    @session.start # Start the browser
    tool = FerrumMCP::Tools::NavigateTool.new(@session.browser_manager)
    result = tool.execute({ url: url })

    unless result[:success]
      puts "  ✗ Navigation failed: #{result[:error]}"
      exit 1
    end

    puts '  ✓ Page loaded successfully'
    puts "  Title: #{result[:data][:title] || 'N/A'}"

    # Wait a bit for cookie banner to appear
    puts '  ⏳ Waiting 3 seconds for cookie banner to appear...'
    sleep 3
    puts
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

  def accept_cookies
    puts '[4/6] Attempting to accept cookies...'
    puts '  Strategies will be tried in order:'
    puts '    1. Common frameworks (OneTrust, Cookiebot, etc.)'
    puts '    2. Iframe detection'
    puts '    3. Text-based detection (multilingual)'
    puts '    4. CSS selectors'
    puts

    tool = FerrumMCP::Tools::AcceptCookiesTool.new(@session.browser_manager)
    @accept_result = tool.execute({ wait: 0 }) # We already waited

    if @accept_result[:success]
      result_data = @accept_result[:data]
      puts '  ✓ Success!'
      puts "  Strategy used: #{result_data[:strategy]}"
      puts "  Selector: #{result_data[:selector]}"
      @acceptance_success = true
      @strategy_used = result_data[:strategy]
      @selector_used = result_data[:selector]
    else
      puts "  ✗ Failed: #{@accept_result[:error]}"
      @acceptance_success = false
    end

    # Wait for any animations/transitions
    sleep 2
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

    if @acceptance_success
      puts '✓ Cookie banner acceptance: SUCCESS'
      puts "  Strategy: #{@strategy_used}"
      puts "  Selector: #{@selector_used}"
      puts
      puts 'Next steps:'
      puts "  1. Open the screenshots in #{OUTPUT_DIR}/"
      puts '  2. Compare before/after to verify the banner was actually closed'
      puts "  3. If it's a false positive, report the selector: #{@selector_used}"
    else
      puts '✗ Cookie banner acceptance: FAILED'
      puts '  No banner detected or unable to click'
      puts
      puts 'Possible reasons:'
      puts '  1. No cookie banner on this page'
      puts '  2. Banner appears after more time (try increasing wait time)'
      puts '  3. Banner uses an unsupported framework'
      puts
      puts 'Manual investigation:'
      puts "  Check the 'before' screenshot to see if a banner is visible"
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
    puts 'Closing session...'
    @session.stop
    puts 'Session closed.'
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
  puts 'Usage: ruby test_cookie_banner.rb <url>'
  puts 'Example: ruby test_cookie_banner.rb https://www.lemonde.fr'
  exit 1
end

url = ARGV[0]

# Validate URL
unless url.match?(%r{^https?://})
  puts 'Error: URL must start with http:// or https://'
  exit 1
end

# Run the test
tester = CookieBannerTester.new(url)
tester.run
