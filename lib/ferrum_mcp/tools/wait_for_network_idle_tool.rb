# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Wait for network idle
    class WaitForNetworkIdleTool < BaseTool
      tool_name 'wait_for_network_idle'
      description 'Wait until the page has no pending network requests (useful after clicks that trigger XHR/fetch)'

      param :timeout, type: :number, default: 30, description: 'Maximum seconds to wait (default: 30)'
      param :connections, type: :integer, default: 0,
                          description: 'Number of pending connections tolerated as "idle" (default: 0)'

      def perform(params)
        ensure_browser_active
        timeout = params[:timeout].to_f
        logger.info "Waiting for network idle (timeout: #{timeout}s)"

        started = monotonic_now
        idle = page.network.wait_for_idle(connections: params[:connections].to_i, timeout: timeout)
        elapsed_ms = ((monotonic_now - started) * 1000).round

        return error_response("Network still busy after #{timeout}s") unless idle

        success_response(idle: true, elapsed_ms: elapsed_ms, url: page.url)
      end
    end
  end
end
