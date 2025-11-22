# frozen_string_literal: true

module FerrumMCP
  module Transport
    # Simple in-memory rate limiter middleware for Rack
    # Limits requests per IP address within a time window
    class RateLimiter
      def initialize(app, options = {})
        @app = app
        @max_requests = options[:max_requests] || 100
        @window = options[:window] || 60 # seconds
        @requests = {}
        @mutex = Mutex.new
      end

      def call(env)
        client_ip = extract_ip(env)

        if rate_limited?(client_ip)
          return rate_limit_response
        end

        track_request(client_ip)
        @app.call(env)
      end

      private

      def extract_ip(env)
        # Check X-Forwarded-For header first (for proxies/load balancers)
        forwarded = env['HTTP_X_FORWARDED_FOR']
        return forwarded.split(',').first.strip if forwarded

        # Fall back to REMOTE_ADDR
        env['REMOTE_ADDR'] || 'unknown'
      end

      def rate_limited?(client_ip)
        @mutex.synchronize do
          cleanup_old_requests

          request_times = @requests[client_ip] || []
          request_times.length >= @max_requests
        end
      end

      def track_request(client_ip)
        @mutex.synchronize do
          @requests[client_ip] ||= []
          @requests[client_ip] << Time.now
        end
      end

      def cleanup_old_requests
        cutoff = Time.now - @window

        @requests.each do |ip, times|
          @requests[ip] = times.select { |t| t > cutoff }
        end

        # Remove IPs with no recent requests
        @requests.delete_if { |_ip, times| times.empty? }
      end

      def rate_limit_response
        [
          429,
          {
            'Content-Type' => 'application/json',
            'Retry-After' => @window.to_s
          },
          [JSON.generate({
            error: 'Rate limit exceeded',
            message: "Maximum #{@max_requests} requests per #{@window} seconds allowed",
            retry_after: @window
          })]
        ]
      end
    end
  end
end
