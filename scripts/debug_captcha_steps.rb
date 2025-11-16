#!/usr/bin/env ruby
# frozen_string_literal: true

# Interactive debug script for CAPTCHA solver
# Usage: ruby scripts/debug_captcha_steps.rb <url>
# This script pauses between steps for manual inspection

require 'bundler/setup'
require_relative '../lib/ferrum_mcp'

require 'fileutils'
require 'json'
require 'base64'

class CaptchaDebugger
  attr_reader :url, :session

  def initialize(url)
    @url = url
    @session = nil
  end

  def run
    puts '=' * 80
    puts 'CAPTCHA Solver Interactive Debugger'
    puts '=' * 80
    puts
    puts 'This script will pause after each step so you can inspect the browser.'
    puts 'Press Enter to continue to the next step...'
    puts

    create_session
    navigate_to_page

    pause('Page loaded. Check if CAPTCHA is visible.')

    detect_checkbox
    pause('Checkbox detected/clicked. Check if challenge appeared.')

    detect_audio_button
    pause('Audio button detected/clicked. Check if audio challenge appeared.')

    detect_audio_source
    pause('Audio source detected. Check the iframe.')

    download_audio if @audio_url

    pause('Done. Press Enter to close browser.')
  ensure
    close_session
  end

  private

  def create_session
    puts '[Step 1] Creating browser session (non-headless for debugging)...'
    config = FerrumMCP::Configuration.new

    @session = FerrumMCP::Session.new(
      config: config,
      options: {
        headless: false,
        timeout: 90,
        browser_options: {
          '--window-size' => '1920,1080',
          '--disable-blink-features' => 'AutomationControlled'
        }
      }
    )

    puts "  ✓ Session created: #{@session.id}"
    puts
  end

  def navigate_to_page
    puts "[Step 2] Navigating to #{url}..."
    @session.start
    tool = FerrumMCP::Tools::NavigateTool.new(@session.browser_manager)
    result = tool.execute({ url: url })

    unless result[:success]
      puts "  ✗ Navigation failed: #{result[:error]}"
      exit 1
    end

    puts '  ✓ Page loaded successfully'
    puts "  Title: #{result[:data][:title]}"

    # Wait for CAPTCHA to load
    sleep 2
    puts
  end

  def detect_checkbox
    puts '[Step 3] Detecting CAPTCHA checkbox...'

    browser = @session.browser_manager.browser

    # Try in iframes
    frames = browser.frames
    puts "  Found #{frames.length} frames total"

    if frames.length > 1
      frames[1..].each_with_index do |frame, index|
        puts "  Checking iframe #{index}..."

        selector = '.recaptcha-checkbox-border'
        element = frame.at_css(selector)

        if element
          puts "    ✓ Found checkbox: #{selector}"
          element.click
          puts "    ✓ Clicked!"
          @checkbox_found = true
          sleep 2 # Wait for challenge to appear
          break
        else
          puts "    ✗ Not found in this iframe"
        end
      rescue StandardError => e
        puts "    ✗ Error: #{e.message}"
      end
    end

    unless @checkbox_found
      puts '  ℹ No checkbox found (may already be visible)'
    end

    puts
  end

  def detect_audio_button
    puts '[Step 4] Detecting audio button...'

    browser = @session.browser_manager.browser
    frames = browser.frames

    puts "  Found #{frames.length} frames"

    # Try main frame first
    selector = '#recaptcha-audio-button'
    element = browser.at_css(selector)

    if element
      puts "  ✓ Found in main frame: #{selector}"
      element.click
      puts '  ✓ Clicked!'
      @audio_button_found = true
      sleep 3
    else
      puts '  ✗ Not in main frame, trying iframes...'

      # Try iframes
      if frames.length > 1
        frames[1..].each_with_index do |frame, index|
          puts "  Checking iframe #{index}..."

          element = frame.at_css(selector)

          if element
            puts "    ✓ Found audio button: #{selector}"
            element.click
            puts "    ✓ Clicked!"
            @audio_button_found = true
            @audio_iframe_index = index
            sleep 3
            break
          else
            puts "    ✗ Not found"
          end
        rescue StandardError => e
          puts "    ✗ Error: #{e.message}"
        end
      end
    end

    unless @audio_button_found
      puts '  ✗ Audio button not found!'
    end

    puts
  end

  def detect_audio_source
    puts '[Step 5] Detecting audio source...'

    browser = @session.browser_manager.browser
    frames = browser.frames

    puts "  Found #{frames.length} frames"

    # Try main frame
    selector = 'audio#audio-source'
    element = browser.at_css(selector)

    if element
      puts "  ✓ Found in main frame: #{selector}"
      @audio_url = element.attribute('src') || element.property('src')
      puts "  Audio URL: #{@audio_url[0..80]}..."
    else
      puts '  ✗ Not in main frame'

      # Try each iframe
      if frames.length > 1
        frames[1..].each_with_index do |frame, index|
          puts "  Checking iframe #{index}..."

          # List all elements in iframe for debugging
          audio_elements = frame.css('audio')
          puts "    Found #{audio_elements.length} <audio> elements"

          audio_elements.each_with_index do |audio_el, i|
            puts "      Audio #{i}:"
            puts "        id: #{audio_el.attribute('id')}"
            puts "        src: #{audio_el.attribute('src') || audio_el.property('src') || 'none'}"

            src = audio_el.attribute('src') || audio_el.property('src')
            if src && !src.empty?
              @audio_url = src
              @audio_iframe_index = index
              puts "      ✓ Using this audio source!"
            end
          end

          # Also check for download links
          links = frame.css('a')
          download_links = links.select { |l| l.text =~ /download/i || l.attribute('class') =~ /download/i }

          if download_links.any?
            puts "    Found #{download_links.length} download links:"
            download_links.each_with_index do |link, i|
              href = link.attribute('href')
              text = link.text
              puts "      Link #{i}: #{text} -> #{href[0..50] if href}..."

              if href && !href.empty? && href.include?('recaptcha')
                @audio_url = href
                @audio_iframe_index = index
                puts "      ✓ Using this download link!"
              end
            end
          end
        rescue StandardError => e
          puts "    ✗ Error accessing iframe: #{e.message}"
        end
      end
    end

    if @audio_url
      puts
      puts "  ✓ Audio URL found: #{@audio_url[0..100]}..."
    else
      puts
      puts '  ✗ No audio source found!'
    end

    puts
  end

  def download_audio
    puts '[Step 6] Downloading audio...'
    puts "  Using curl to download from: #{@audio_url[0..80]}..."

    temp_file = Tempfile.new(['debug_audio', '.mp3'])
    temp_file.close

    stdout, stderr, status = Open3.capture3("curl -s -L -o #{temp_file.path} #{@audio_url.shellescape}")

    if status.success?
      size = File.size(temp_file.path)
      puts "  ✓ Downloaded: #{size} bytes"
      puts "  Saved to: #{temp_file.path}"

      if size.positive?
        puts
        puts '  Testing Whisper transcription...'
        whisper = FerrumMCP::WhisperService.new(logger: Logger.new($stdout))
        transcription = whisper.transcribe(temp_file.path)
        puts "  Transcription: #{transcription}"
      else
        puts '  ✗ File is empty!'
      end
    else
      puts "  ✗ Download failed: #{stderr}"
    end

    puts
  rescue StandardError => e
    puts "  ✗ Error: #{e.message}"
    puts
  ensure
    temp_file&.unlink
  end

  def pause(message)
    puts "━━━ #{message} ━━━"
    print 'Press Enter to continue... '
    $stdin.gets
    puts
  end

  def close_session
    return unless @session

    @session.stop
    puts 'Session closed.'
  rescue StandardError => e
    puts "Error closing session: #{e.message}"
  end
end

# Main execution
if ARGV.empty?
  puts 'Usage: ruby scripts/debug_captcha_steps.rb <url>'
  puts
  puts 'Example:'
  puts '  ruby scripts/debug_captcha_steps.rb https://www.google.com/recaptcha/api2/demo'
  puts
  exit 1
end

url = ARGV[0]

unless url.match?(%r{^https?://})
  puts 'Error: URL must start with http:// or https://'
  exit 1
end

debugger = CaptchaDebugger.new(url)
debugger.run
