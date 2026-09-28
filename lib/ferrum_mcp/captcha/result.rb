# frozen_string_literal: true

module FerrumMCP
  module Captcha
    # Outcome of a solving attempt.
    #
    # status:
    #   :solved             - the widget reports success and a token is available
    #   :blocked            - the provider refuses to serve challenges (rate limit, bot flag)
    #   :distrusted         - the provider only serves unsolvable decoy challenges
    #   :challenge_required - a visual challenge appeared that cannot be solved automatically
    #   :failed             - attempts exhausted or the widget never reached a solved state
    Result = Struct.new(:type, :status, :token, :attempts, :message, :details, keyword_init: true) do
      def self.solved(type, token:, attempts: 0, message: nil, **details)
        new(type: type, status: :solved, token: token, attempts: attempts, message: message, details: details)
      end

      def self.unsolved(type, status, message, attempts: 0, **details)
        new(type: type, status: status, token: nil, attempts: attempts, message: message, details: details)
      end

      def solved?
        status == :solved
      end

      def to_h
        {
          solved: solved?,
          type: type.to_s,
          status: status.to_s,
          attempts: attempts,
          message: message,
          token: token,
          token_length: token&.length
        }.merge(details || {}).compact
      end
    end
  end
end
