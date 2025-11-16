#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to analyze what cookie-related elements are found on a page
# This helps identify false positives and improve detection
# Usage: ruby analyze_cookie_detection.rb <url>

require 'bundler/setup'
require_relative 'lib/ferrum_mcp'
require 'json'

class CookieDetectionAnalyzer
  def initialize(url)
    @url = url
    @session = nil
  end

  def run
    puts '=' * 80
    puts 'Cookie Banner Detection Analysis'
    puts "URL: #{@url}"
    puts '=' * 80
    puts

    create_session
    navigate_to_page
    analyze_page
  ensure
    close_session
  end

  private

  def create_session
    puts '[1/3] Creating browser session...'
    config = FerrumMCP::Configuration.new

    @session = FerrumMCP::Session.new(
      config: config,
      options: {
        headless: false,
        timeout: 60,
        browser_options: { '--window-size' => '1920,1080' }
      }
    )

    puts '  ✓ Session created'
    puts
  end

  def navigate_to_page
    puts '[2/3] Navigating to page...'
    @session.start
    tool = FerrumMCP::Tools::NavigateTool.new(@session.browser_manager)
    result = tool.execute({ url: @url })

    unless result[:success]
      puts "  ✗ Navigation failed: #{result[:error]}"
      exit 1
    end

    puts '  ✓ Page loaded'
    sleep 3 # Wait for cookie banner
    puts
  end

  def analyze_page
    puts '[3/3] Analyzing page elements...'
    puts

    browser = @session.browser_manager.browser

    # Common patterns from accept_cookies_tool.rb
    patterns = [
      'accept all cookies', 'accept all', 'accept cookies', 'accept and continue',
      'allow all', 'continue',
      'accepter et continuer', 'tout accepter', 'accepter'
    ]

    puts 'Searching for elements matching cookie patterns...'
    puts '-' * 80

    patterns.each do |pattern|
      puts "\nPattern: '#{pattern}'"
      puts '  Searching for buttons...'

      # Find buttons with this text
      begin
        escaped = escape_xpath_string(pattern)
        xpath = "//button[contains(translate(normalize-space(.), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), #{escaped})]"

        elements = browser.xpath(xpath)

        if elements.empty?
          puts '    No buttons found'
        else
          puts "    Found #{elements.length} button(s):"
          elements.first(3).each_with_index do |el, i|
            text = begin
              el.text.strip
            rescue StandardError
              '[could not get text]'
            end
            visible = begin
              element_visible?(el)
            rescue StandardError
              false
            end
            classes = begin
              el.attribute('class')
            rescue StandardError
              ''
            end || ''
            id = begin
              el.attribute('id')
            rescue StandardError
              ''
            end || ''

            puts "      [#{i + 1}] Text: '#{text[0..80]}#{'...' if text.length > 80}'"
            puts "          Visible: #{visible}"
            puts "          ID: #{id}" unless id.empty?
            puts "          Classes: #{classes}" unless classes.empty?
            puts "          Context: Cookie-related? #{looks_like_cookie_button?(text, classes, id)}"
          end
        end
      rescue StandardError => e
        puts "    Error: #{e.message}"
      end
    end

    puts "\n"
    puts '-' * 80
    puts 'Looking for cookie-related iframes...'
    iframes = browser.css('iframe')
    puts "  Found #{iframes.length} iframe(s)"

    iframes.first(5).each_with_index do |iframe, i|
      src = begin
        iframe.attribute('src')
      rescue StandardError
        ''
      end || ''
      id = begin
        iframe.attribute('id')
      rescue StandardError
        ''
      end || ''
      title = begin
        iframe.attribute('title')
      rescue StandardError
        ''
      end || ''

      cookie_related = src.to_s.match?(/cookie|consent|gdpr|privacy/i) ||
                       id.to_s.match?(/cookie|consent|gdpr|privacy/i) ||
                       title.to_s.match?(/cookie|consent|gdpr|privacy/i)

      puts "    [#{i + 1}] #{cookie_related ? '🍪' : '  '} ID: #{id}, Title: #{title}"
      puts "        Src: #{src[0..80]}#{'...' if src.length > 80}" unless src.empty?
    end

    puts "\n"
    puts '-' * 80
    puts 'Recommendations:'
    puts "  1. Check if any 'continue' buttons are NOT cookie-related"
    puts '  2. Look for more specific cookie banner frameworks'
    puts '  3. Consider adding context checks (parent element, nearby text, etc.)'
    puts '=' * 80
  end

  def looks_like_cookie_button?(text, classes, id)
    cookie_keywords = /cookie|consent|gdpr|privacy|rgpd/i

    text.match?(cookie_keywords) ||
      classes.to_s.match?(cookie_keywords) ||
      id.to_s.match?(cookie_keywords)
  end

  def element_visible?(element)
    # Check if element is visible
    return false unless element

    begin
      # Check computed style
      script = <<~JAVASCRIPT
        const el = arguments[0];
        const style = window.getComputedStyle(el);
        const rect = el.getBoundingClientRect();
        return style.display !== 'none' &&
               style.visibility !== 'hidden' &&
               style.opacity !== '0' &&
               rect.width > 0 &&
               rect.height > 0;
      JAVASCRIPT

      @session.browser_manager.browser.evaluate(script, element)
    rescue StandardError
      false
    end
  end

  def escape_xpath_string(text)
    return "'#{text.downcase}'" unless text.include?("'")

    parts = text.downcase.split("'")
    quoted_parts = parts.map { |part| "'#{part}'" }
    "concat(#{quoted_parts.join(", \"'\", ")})"
  end

  def close_session
    return unless @session

    puts "\nClosing session..."
    @session.stop
  end
end

# Main
if ARGV.empty?
  puts 'Usage: ruby analyze_cookie_detection.rb <url>'
  puts 'Example: ruby analyze_cookie_detection.rb https://www.lemonde.fr'
  exit 1
end

url = ARGV[0]
unless url.match?(%r{^https?://})
  puts 'Error: URL must start with http:// or https://'
  exit 1
end

analyzer = CookieDetectionAnalyzer.new(url)
analyzer.run
