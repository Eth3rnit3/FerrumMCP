# frozen_string_literal: true

require 'openssl'

module FerrumMCP
  module Transport
    # Rack middleware for API key authentication using Bearer tokens
    # Validates Authorization header against configured API keys
    class ApiKeyAuthenticator
      AUTHORIZATION_HEADER = 'HTTP_AUTHORIZATION'
      BEARER_PREFIX = 'Bearer '

      def initialize(app, options = {})
        @app = app
        @api_keys = options[:api_keys] || []
        @logger = options[:logger]
        @skip_paths = options[:skip_paths] || []
      end

      def call(env)
        path = env['PATH_INFO'] || '/'

        # Skip authentication for configured paths (e.g., /health)
        return @app.call(env) if skip_authentication?(path)

        # Extract and validate token
        token = extract_bearer_token(env)

        if token.nil?
          log_auth_failure('Missing Authorization header', env)
          return unauthorized_response('Missing Authorization header')
        end

        unless valid_token?(token)
          log_auth_failure('Invalid API key', env)
          return unauthorized_response('Invalid API key')
        end

        @app.call(env)
      end

      private

      def skip_authentication?(path)
        @skip_paths.any? { |skip_path| path == skip_path || path.start_with?("#{skip_path}/") }
      end

      def extract_bearer_token(env)
        auth_header = env[AUTHORIZATION_HEADER]
        return nil if auth_header.nil? || auth_header.empty?
        return nil unless auth_header.start_with?(BEARER_PREFIX)

        auth_header[BEARER_PREFIX.length..]
      end

      def valid_token?(token)
        return false if token.nil? || token.empty?
        return false if @api_keys.empty?

        # Use constant-time comparison to prevent timing attacks
        @api_keys.any? { |key| secure_compare(key, token) }
      end

      # Constant-time string comparison to prevent timing attacks
      def secure_compare(expected, actual)
        return false if expected.nil? || actual.nil?
        return false if expected.bytesize != actual.bytesize

        # Use OpenSSL's secure_compare if available (Ruby 2.5+)
        if OpenSSL.respond_to?(:secure_compare)
          OpenSSL.secure_compare(expected, actual)
        else
          # Fallback for older Ruby versions
          left = expected.unpack('C*')
          right = actual.unpack('C*')
          result = 0
          left.zip(right) { |x, y| result |= x ^ y }
          result.zero?
        end
      end

      def log_auth_failure(reason, env)
        return unless @logger

        client_ip = extract_ip(env)
        path = env['PATH_INFO'] || '/'
        method = env['REQUEST_METHOD'] || 'UNKNOWN'

        @logger.warn("Authentication failed: #{reason} - IP: #{client_ip}, #{method} #{path}")
      end

      def extract_ip(env)
        forwarded = env['HTTP_X_FORWARDED_FOR']
        return forwarded.split(',').first.strip if forwarded

        env['REMOTE_ADDR'] || 'unknown'
      end

      def unauthorized_response(message)
        [
          401,
          {
            'Content-Type' => 'application/json',
            'WWW-Authenticate' => 'Bearer realm="ferrum-mcp"'
          },
          [JSON.generate({
                           error: 'Unauthorized',
                           message: message
                         })]
        ]
      end
    end
  end
end
