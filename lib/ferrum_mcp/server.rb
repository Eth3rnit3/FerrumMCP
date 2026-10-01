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
      Tools::ScrollTool,
      Tools::SelectOptionTool,
      Tools::UploadFileTool,
      # Extraction
      Tools::SnapshotTool,
      Tools::GetTextTool,
      Tools::GetHTMLTool,
      Tools::ScreenshotTool,
      Tools::GetTitleTool,
      Tools::GetURLTool,
      Tools::FindByTextTool,
      # Waiting
      Tools::WaitForSelectorTool,
      Tools::WaitForTextTool,
      Tools::WaitForNetworkIdleTool,
      # Tabs & viewport
      Tools::ListTabsTool,
      Tools::NewTabTool,
      Tools::SwitchTabTool,
      Tools::CloseTabTool,
      Tools::SetViewportTool,
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
      @mcp_server = create_mcp_server

      setup_tools
      setup_resources
      setup_error_handling
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
      progress = progress_reporter(params[:server_context])
      params = params.except(:server_context)
      logger.debug "Executing tool: #{tool_class.tool_name}"

      result = if tool_class.requires_session?
                 execute_browser_tool(tool_class, params, progress)
               else
                 tool_class.new(session_manager).execute(params)
               end

      to_mcp_response(tool_class, result)
    rescue StandardError => e
      logger.error "Tool execution error (#{tool_class.tool_name}): #{e.class} - #{e.message}"
      logger.error e.backtrace.first(10).join("\n")
      error_tool_response("#{e.class}: #{e.message}")
    end

    def execute_browser_tool(tool_class, params, progress)
      session_id = params[:session_id] || params['session_id']
      if session_id.nil? || session_id.to_s.empty?
        logger.error "session_id is required for #{tool_class.tool_name}"
        return { success: false, error: 'session_id is required. Create a session first using create_session tool.' }
      end

      session_manager.with_session(session_id) do |browser_manager|
        tool_class.new(browser_manager, progress: progress).execute(params)
      end
    end

    # notifications/progress for the running tool call, nil when the SDK gave
    # no server context (a direct call) or the client sent no progress token
    # (the SDK then drops the report itself).
    def progress_reporter(server_context)
      return unless server_context.respond_to?(:report_progress)

      lambda do |current, total, message|
        server_context.report_progress(current, total: total, message: message)
      rescue StandardError => e
        logger.debug "Progress notification failed: #{e.message}"
      end
    end

    def to_mcp_response(tool_class, result)
      unless result[:success]
        logger.error "Tool #{tool_class.tool_name} failed: #{result[:error]}"
        return error_tool_response(result[:error], image: result[:image])
      end

      if result[:type] == 'image'
        MCP::Tool::Response.new([{ type: 'image', data: result[:data], mimeType: result[:mime_type] }])
      else
        MCP::Tool::Response.new([{ type: 'text', text: result[:data].to_json }])
      end
    end

    def setup_error_handling
      MCP.configure do |mcp_config|
        mcp_config.exception_reporter = ->(exception, context) { report_exception(exception, context) }
        mcp_config.instrumentation_callback = lambda { |data|
          logger.debug "MCP Method: #{data[:method]}, Duration: #{data[:duration]}s"
        }
      end
    end

    def report_exception(exception, _context)
      logger.error '=' * 80
      logger.error "MCP Exception: #{exception.class} - #{exception.message}"
      original = exception.respond_to?(:original_error) ? exception.original_error : nil
      if original
        logger.error "ORIGINAL ERROR: #{original.class} - #{original.message}"
        logger.error original.backtrace.first(15).join("\n")
      end
      logger.error exception.backtrace.join("\n")
      logger.error '=' * 80
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
    # An optional base64 PNG shows the agent what went wrong (e.g. a CAPTCHA challenge)
    def error_tool_response(message, image: nil)
      content = [{ type: 'text', text: message }]
      content << { type: 'image', data: image, mimeType: 'image/png' } if image
      MCP::Tool::Response.new(content, error: true)
    end
  end
end
