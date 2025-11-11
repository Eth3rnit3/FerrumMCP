#!/bin/bash

# Clean start script for Ferrum MCP Server

# Kill any existing server
pkill -9 -f "ruby.*server.rb" 2>/dev/null

# Wait a bit
sleep 1

# Check port is free
if lsof -ti:3000 > /dev/null 2>&1; then
    echo "ERROR: Port 3000 is still in use"
    exit 1
fi

# Clear old log
rm -f logs/ferrum_mcp.log

# Start server
echo "Starting Ferrum MCP Server..."
bundle exec ruby server.rb
