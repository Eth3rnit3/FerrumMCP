# frozen_string_literal: true

module FerrumMCP
  # Main MCP Server implementation
  class Server
    attr_reader :mcp_server, :session_manager, :resource_manager, :config, :logger

    TOOL_CLASSES = [
      # Session Management
      Tools::CreateSessionTool,
      Tools::ListSessionsTool,
      Tools::CloseSessionTool,
      Tools::GetSessionInfoTool,
      # Navigation
      Tools::NavigateTool,
      Tools::GoBackTool,
      Tools::GoForwardTool,
      Tools::RefreshTool,
      # Interaction
      Tools::ClickTool,
      Tools::FillFormTool,
      Tools::PressKeyTool,
      Tools::HoverTool,
      Tools::DragAndDropTool,
      Tools::AcceptCookiesTool,
      Tools::SolveCaptchaTool,
      # Extraction
      Tools::GetTextTool,
      Tools::GetHTMLTool,
      Tools::ScreenshotTool,
      Tools::GetTitleTool,
      Tools::GetURLTool,
      Tools::FindByTextTool,
      # Advanced
      Tools::ExecuteScriptTool,
      Tools::EvaluateJSTool,
      Tools::GetCookiesTool,
      Tools::SetCookieTool,
      Tools::ClearCookiesTool,
      Tools::GetAttributeTool,
      Tools::QueryShadowDOMTool
    ].freeze

    def initialize(config = Configuration.new)
      @config = config
      @logger = config.logger
      @session_manager = SessionManager.new(config)
      @resource_manager = ResourceManager.new(config)
      @tool_instances = {}
      @mcp_server = create_mcp_server

      setup_tools
      setup_resources
      setup_error_handling
    end

    # Deprecated: For backward compatibility
    # Sessions must be created explicitly using create_session tool
    def start_browser
      raise NotImplementedError, 'start_browser is deprecated. Use create_session tool to create a session.'
    end

    # Deprecated: For backward compatibility
    def stop_browser
      logger.warn 'stop_browser is deprecated, use session_manager.close_all_sessions'
      session_manager.close_all_sessions
      @tool_instances = {}
      logger.info 'All sessions stopped'
    end

    # Shutdown server and cleanup all sessions
    def shutdown
      logger.info 'Shutting down server...'
      session_manager.shutdown
      logger.info 'Server shutdown complete'
    end

    def handle_request(json_request)
      request = JSON.parse(json_request)
      logger.debug "Received request: #{request['method']}"

      mcp_server.handle_request(request)
    rescue JSON::ParserError => e
      logger.error "Invalid JSON request: #{e.message}"
      error_response('Invalid JSON request')
    rescue StandardError => e
      logger.error "Request handling error: #{e.message}"
      logger.error e.backtrace.join("\n")
      error_response(e.message)
    end

    private

    def create_mcp_server
      MCP::Server.new(
        name: 'ferrum-browser',
        version: FerrumMCP::VERSION,
        instructions: 'A browser automation server using Ferrum and BotBrowser for web scraping and testing',
        resources: resource_manager.resources
      )
    end

    def setup_tools
      # Capture references to instance variables for use in the block
      server_instance = self

      TOOL_CLASSES.each do |tool_class|
        mcp_server.define_tool(
          name: tool_class.tool_name,
          description: tool_class.description,
          input_schema: tool_class.input_schema
        ) do |**params|
          # Call execute_tool on the server instance
          server_instance.send(:execute_tool, tool_class, params)
        end
      end

      logger.info "Registered #{TOOL_CLASSES.length} tools"
    end

    def setup_resources
      # Capture references to instance variables for use in the block
      manager = resource_manager

      # Define the resources_read handler
      mcp_server.resources_read_handler do |params|
        uri = params[:uri]
        logger.debug "Reading resource: #{uri}"

        result = manager.read_resource(uri)
        if result
          [result]
        else
          logger.error "Resource not found: #{uri}"
          []
        end
      end

      logger.info "Registered #{resource_manager.resources.length} resources"
    end

    def execute_tool(tool_class, params)
      logger.debug "Executing tool: #{tool_class.tool_name} with params: #{params.inspect}"

      # Session management tools don't need a browser session
      if session_management_tool?(tool_class)
        logger.debug "Executing session management tool: #{tool_class.tool_name}"
        tool = tool_class.new(session_manager)
        result = tool.execute(params)
      else
        # Extract session_id from params (required)
        session_id = params[:session_id] || params['session_id']

        unless session_id
          logger.error "session_id is required for #{tool_class.tool_name}"
          return error_tool_response('session_id is required. Create a session first using create_session tool.')
        end

        logger.debug "Using session_id: #{session_id}"

        # Execute tool within session context
        result = session_manager.with_session(session_id) do |browser_manager|
          logger.debug "Creating tool instance for #{tool_class.tool_name}"
          tool = tool_class.new(browser_manager)
          logger.debug "Calling execute on #{tool_class.tool_name}"
          tool.execute(params)
        end
      end

      logger.debug "Tool #{tool_class.tool_name} result: #{result.inspect}"

      # MCP expects a Tool::Response object
      # Convert our tool result to MCP format
      if result[:success]
        logger.debug "Tool succeeded, creating MCP::Tool::Response with data: #{result[:data].inspect}"

        # Check if this is an image response
        if result[:type] == 'image'
          logger.debug "Creating image response with mime_type: #{result[:mime_type]}"
          # Return MCP Tool::Response with image content
          MCP::Tool::Response.new([{
                                    type: 'image',
                                    data: result[:data],
                                    mimeType: result[:mime_type]
                                  }])
        else
          # Return a proper MCP Tool::Response with the data as text content
          MCP::Tool::Response.new([{ type: 'text', text: result[:data].to_json }])
        end
      else
        logger.error "Tool failed with error: #{result[:error]}"
        # Return an error response
        MCP::Tool::Response.new([{ type: 'text', text: result[:error] }], error: true)
      end
    rescue StandardError => e
      logger.error "Tool execution error (#{tool_class.tool_name}): #{e.class} - #{e.message}"
      logger.error 'Backtrace:'
      logger.error e.backtrace.first(10).join("\n")
      # Return an error response for unexpected exceptions
      MCP::Tool::Response.new([{ type: 'text', text: "#{e.class}: #{e.message}" }], error: true)
    end

    # Check if tool is a session management tool
    def session_management_tool?(tool_class)
      [
        Tools::CreateSessionTool,
        Tools::ListSessionsTool,
        Tools::CloseSessionTool,
        Tools::GetSessionInfoTool
      ].include?(tool_class)
    end

    def setup_error_handling
      MCP.configure do |mcp_config|
        mcp_config.exception_reporter = lambda { |exception, context|
          logger.error '=' * 80
          logger.error "MCP Exception: #{exception.class} - #{exception.message}"
          logger.error "Context: #{context.inspect}"

          # Log the original error if there is one
          if exception.respond_to?(:original_error) && exception.original_error
            logger.error "ORIGINAL ERROR: #{exception.original_error.class} - #{exception.original_error.message}"
            logger.error 'ORIGINAL BACKTRACE:'
            logger.error exception.original_error.backtrace.first(15).join("\n")
          end

          logger.error 'Exception backtrace:'
          logger.error exception.backtrace.join("\n")
          logger.error '=' * 80
        }

        mcp_config.instrumentation_callback = lambda { |data|
          logger.debug "MCP Method: #{data[:method]}, Duration: #{data[:duration]}s"
        }
      end
    end

    def error_response(message)
      {
        jsonrpc: '2.0',
        error: {
          code: -32_603,
          message: message
        },
        id: nil
      }
    end

    # Helper to create error response for tool execution
    def error_tool_response(message)
      MCP::Tool::Response.new([{ type: 'text', text: message }], error: true)
    end
  end
end
