# frozen_string_literal: true

module FerrumMCP
  # Main MCP Server implementation
  class Server
    attr_reader :mcp_server, :browser_manager, :config, :logger

    TOOL_CLASSES = [
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
      # Extraction
      Tools::GetTextTool,
      Tools::GetHTMLTool,
      Tools::ScreenshotTool,
      Tools::GetTitleTool,
      Tools::GetURLTool,
      # Waiting
      Tools::WaitForElementTool,
      Tools::WaitForNavigationTool,
      Tools::WaitTool,
      # Advanced
      Tools::ExecuteScriptTool,
      Tools::EvaluateJSTool,
      Tools::GetCookiesTool,
      Tools::SetCookieTool,
      Tools::ClearCookiesTool,
      Tools::GetAttributeTool
    ].freeze

    def initialize(config = Configuration.new)
      @config = config
      @logger = config.logger
      @browser_manager = BrowserManager.new(config)
      @mcp_server = create_mcp_server
      @tool_instances = {}

      setup_tools
      setup_error_handling
    end

    def start_browser
      logger.info 'Starting browser...'
      browser_manager.start
      initialize_tool_instances
      logger.info 'Browser ready'
    end

    def stop_browser
      logger.info 'Stopping browser...'
      browser_manager.stop
      @tool_instances = {}
      logger.info 'Browser stopped'
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
        instructions: 'A browser automation server using Ferrum and BotBrowser for web scraping and testing'
      )
    end

    def setup_tools
      TOOL_CLASSES.each do |tool_class|
        mcp_server.define_tool(
          name: tool_class.tool_name,
          description: tool_class.description,
          input_schema: tool_class.input_schema
        ) do |**params|
          execute_tool(tool_class, params)
        end
      end

      logger.info "Registered #{TOOL_CLASSES.length} tools"
    end

    def initialize_tool_instances
      @tool_instances = {}
      TOOL_CLASSES.each do |tool_class|
        @tool_instances[tool_class] = tool_class.new(browser_manager)
      end
    end

    def execute_tool(tool_class, params)
      # Start browser if not active
      start_browser unless browser_manager.active?

      tool = @tool_instances[tool_class] || tool_class.new(browser_manager)
      result = tool.execute(params)

      logger.debug "Tool #{tool_class.tool_name} result: #{result[:success] ? 'success' : 'error'}"
      result
    rescue StandardError => e
      logger.error "Tool execution error (#{tool_class.tool_name}): #{e.message}"
      logger.error e.backtrace.first(5).join("\n")
      { success: false, error: e.message }
    end

    def setup_error_handling
      MCP.configure do |mcp_config|
        mcp_config.exception_reporter = lambda { |exception, context|
          logger.error "MCP Exception: #{exception.message}"
          logger.error "Context: #{context.inspect}"
          logger.error exception.backtrace.join("\n")
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
          code: -32603,
          message: message
        },
        id: nil
      }
    end
  end
end
