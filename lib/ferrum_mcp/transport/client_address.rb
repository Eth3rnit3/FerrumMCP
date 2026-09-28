# frozen_string_literal: true

module FerrumMCP
  module Transport
    # Resolves the client IP of a Rack request.
    #
    # X-Forwarded-For is only honoured when the server is explicitly configured
    # as sitting behind a trusted proxy; otherwise any client could rotate the
    # header to escape rate limiting or forge audit logs.
    module ClientAddress
      module_function

      def extract(env, trust_proxy: false)
        if trust_proxy
          forwarded = env['HTTP_X_FORWARDED_FOR'].to_s.split(',').first&.strip
          return forwarded unless forwarded.nil? || forwarded.empty?
        end

        env['REMOTE_ADDR'] || 'unknown'
      end
    end
  end
end
