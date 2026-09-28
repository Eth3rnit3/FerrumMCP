# frozen_string_literal: true

module FerrumMCP
  # Fixes applied to Ferrum before any browser starts.
  module FerrumPatches
    # Ferrum auto-attaches to every new target with waitForDebuggerOnStart but
    # only resumes pages and iframes (Ferrum::Contexts::ALLOWED_TARGET_TYPES).
    # Service workers, shared workers, extension background pages and browser
    # UI stayed paused forever: site service workers never activated, and the
    # browser ran with frozen internals no regular Chrome has.
    # Resume them (no domain is enabled on them). Detaching right after the
    # resume raced with it and left the target paused.
    module ResumeBackgroundTargets
      private

      def subscribe
        super
        @client.on('Target.attachedToTarget') do |params|
          next if Ferrum::Contexts::ALLOWED_TARGET_TYPES.include?(params.dig('targetInfo', 'type'))

          if params['waitingForDebugger']
            @client.session(params['sessionId']).command('Runtime.runIfWaitingForDebugger', async: true)
          end
        end
      end
    end

    def self.apply!
      return if Ferrum::Contexts.include?(ResumeBackgroundTargets)

      Ferrum::Contexts.prepend(ResumeBackgroundTargets)
    end
  end
end
