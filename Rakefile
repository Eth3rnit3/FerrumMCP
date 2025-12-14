# frozen_string_literal: true

require 'bundler/setup'
require 'bundler/gem_tasks'

desc 'Start the MCP server'
task :server do
  ruby 'bin/ferrum-mcp'
end

desc 'Run RuboCop'
task :rubocop do
  sh 'bundle exec rubocop'
end

desc 'Run RuboCop with auto-correct'
task :rubocop_fix do
  sh 'bundle exec rubocop -A'
end

desc 'Run tests'
task :test do
  sh 'bundle exec rspec'
end

desc 'List all available tools'
task :list_tools do
  require_relative 'lib/ferrum_mcp'

  puts "\nAvailable Tools in Ferrum MCP Server:\n"
  puts '=' * 60

  FerrumMCP::Server::TOOL_CLASSES.each_with_index do |tool_class, index|
    puts "\n#{index + 1}. #{tool_class.tool_name}"
    puts "   Description: #{tool_class.description}"
    puts "   Input Schema: #{tool_class.input_schema.inspect}"
  end

  puts "\n#{'=' * 60}"
  puts "Total: #{FerrumMCP::Server::TOOL_CLASSES.length} tools"
  puts ''
end

desc 'Check environment configuration'
task :check_env do
  puts "\nEnvironment Configuration Check:\n"
  puts '=' * 60

  env_vars = {
    'BROWSER_PATH' => ENV['BROWSER_PATH'] || ENV.fetch('BOTBROWSER_PATH', nil),
    'BOTBROWSER_PROFILE' => ENV.fetch('BOTBROWSER_PROFILE', nil),
    'MCP_SERVER_HOST' => ENV.fetch('MCP_SERVER_HOST', '0.0.0.0'),
    'MCP_SERVER_PORT' => ENV.fetch('MCP_SERVER_PORT', '3000'),
    'BROWSER_HEADLESS' => ENV.fetch('BROWSER_HEADLESS', 'false'),
    'BROWSER_TIMEOUT' => ENV.fetch('BROWSER_TIMEOUT', '60'),
    'LOG_LEVEL' => ENV.fetch('LOG_LEVEL', 'info')
  }

  env_vars.each do |key, value|
    status = value.nil? || value.empty? ? '⚪' : '✅'
    display_value = if key == 'BROWSER_PATH'
                      value || '(will use system Chrome/Chromium)'
                    else
                      value || '(not set)'
                    end
    puts "#{status} #{key}: #{display_value}"
  end

  puts "\n#{'=' * 60}"

  # Check browser configuration
  browser_path = env_vars['BROWSER_PATH']

  if browser_path.nil? || browser_path.empty?
    puts '⚪ Browser: Will use system Chrome/Chromium (auto-detect)'
    puts '   This works fine for basic usage!'
  elsif File.exist?(browser_path)
    puts "✅ Browser binary found at: #{browser_path}"
  else
    puts "❌ Browser binary not found at: #{browser_path}"
  end

  # Check if using BotBrowser profile
  profile = env_vars['BOTBROWSER_PROFILE']

  if profile && !profile.empty?
    if File.exist?(profile)
      puts "✅ BotBrowser profile found: #{profile}"
      puts '   Anti-detection mode enabled!'
    else
      puts "⚠️  BotBrowser profile configured but not found: #{profile}"
    end
  else
    puts '⚪ No BotBrowser profile configured'
    puts '   Consider using BotBrowser for better stealth!'
    puts '   Get it at: https://github.com/botswin/BotBrowser'
  end

  puts ''
end

desc 'Show project structure'
task :structure do
  puts "\nProject Structure:\n"
  puts '=' * 60
  sh 'tree -I "bin|.git" -L 3 || find . -type d -not -path "*/.*" -not -path "*/bin/*" | sed "s/[^/]*\\//|  /g"'
end

task default: :check_env
