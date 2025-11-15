#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to add session_id parameter to all existing tool schemas

require 'fileutils'

TOOLS_DIR = File.expand_path('../lib/ferrum_mcp/tools', __dir__)

# Tools that should NOT have session_id (session management tools)
EXCLUDED_TOOLS = %w[
  session_tools.rb
  base_tool.rb
].freeze

SESSION_ID_PROPERTY = <<~RUBY.chomp
  session_id: {
                type: 'string',
                description: 'Optional: Session ID to use (omit for default session)'
              }
RUBY

def should_process_file?(filename)
  filename.end_with?('_tool.rb') && !EXCLUDED_TOOLS.include?(File.basename(filename))
end

def already_has_session_id?(content)
  content.include?('session_id:') && content.include?('Session ID to use')
end

def add_session_id_to_schema(content)
  # Find the input_schema method
  schema_start = content.index(/def self\.input_schema\s*\n\s*\{/)
  return content unless schema_start

  # Find the properties section
  properties_match = content.match(/properties:\s*\{/, schema_start)
  return content unless properties_match

  # Find the position after the opening brace of properties
  insert_pos = properties_match.end(0)

  # Check if there are already properties defined
  # We need to find where to insert (after last property or as first property)
  next_section = content.index(/\n\s+\},?\s*\n\s+(required:|additionalProperties:|\})/, insert_pos)

  if next_section
    # Find the last property before next_section
    last_property = content.rindex(/\}[,\s]*\n/, next_section)

    if last_property && last_property > insert_pos
      # Add comma to last property if needed
      content.insert(last_property + 1, ',') unless content[last_property..next_section].include?(',')

      # Insert session_id after the last property
      insert_position = content.index("\n", last_property + 1)
      indent = content[(insert_position + 1)..(insert_position + 20)].match(/^\s*/)[0]
      content.insert(insert_position + 1, "#{indent}#{SESSION_ID_PROPERTY},\n")
    else
      # No properties yet, insert as first property
      content.insert(insert_pos, "\n            #{SESSION_ID_PROPERTY}")
    end
  end

  content
end

def process_file(filepath) # rubocop:disable Naming/PredicateMethod
  filename = File.basename(filepath)
  puts "Processing #{filename}..."

  content = File.read(filepath)

  if already_has_session_id?(content)
    puts '  ✓ Already has session_id parameter, skipping'
    return false
  end

  updated_content = add_session_id_to_schema(content)

  if updated_content == content
    puts '  ⚠ Could not add session_id (schema format not recognized)'
    false
  else
    File.write(filepath, updated_content)
    puts '  ✓ Added session_id parameter'
    true
  end
end

# Main execution
puts 'Adding session_id parameter to all tools...'
puts '=' * 50

processed_count = 0
updated_count = 0

Dir.glob(File.join(TOOLS_DIR, '*.rb')).each do |filepath|
  next unless should_process_file?(filepath)

  processed_count += 1
  updated_count += 1 if process_file(filepath)
end

puts '=' * 50
puts "Processed #{processed_count} tools"
puts "Updated #{updated_count} tools"
puts "Skipped #{processed_count - updated_count} tools (already up-to-date)"
