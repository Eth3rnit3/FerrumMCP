#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require_relative 'lib/ferrum_mcp'

puts '=' * 60
puts 'Test Browser Navigation'
puts '=' * 60
puts ''

# Create configuration
config = FerrumMCP::Configuration.new
puts 'Configuration:'
puts "  Browser path: #{config.browser_path || 'System Chrome (auto-detect)'}"
puts "  Headless: #{config.headless}"
puts "  Timeout: #{config.timeout}s"
puts ''

# Create browser manager
puts 'Creating browser manager...'
browser_manager = FerrumMCP::BrowserManager.new(config)

begin
  # Start browser
  puts 'Starting browser...'
  browser = browser_manager.start
  puts '✓ Browser started successfully!'
  puts ''

  # Navigate to leboncoin
  puts 'Navigating to https://www.leboncoin.fr ...'
  browser.goto('https://www.leboncoin.fr')
  puts '✓ Navigation successful!'
  puts ''

  # Get page info
  puts 'Page information:'
  puts "  URL: #{browser.url}"
  puts "  Title: #{browser.title}"
  puts ''

  # Wait a bit to see the browser
  puts 'Waiting 3 seconds (you should see the browser window)...'
  sleep 3

  # Take a screenshot
  screenshot_path = '/tmp/leboncoin_test.png'
  puts "Taking screenshot to #{screenshot_path}..."
  browser.screenshot(path: screenshot_path)
  puts '✓ Screenshot saved!'
  puts ''

  puts '=' * 60
  puts 'SUCCESS! Browser is working correctly.'
  puts '=' * 60
rescue StandardError => e
  puts ''
  puts '=' * 60
  puts "ERROR: #{e.class}"
  puts "Message: #{e.message}"
  puts '=' * 60
  puts ''
  puts 'Backtrace:'
  puts e.backtrace.first(10).join("\n")
ensure
  # Stop browser
  if browser_manager
    puts ''
    puts 'Stopping browser...'
    browser_manager.stop
    puts '✓ Browser stopped'
  end
end
