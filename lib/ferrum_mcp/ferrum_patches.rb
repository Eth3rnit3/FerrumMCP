# frozen_string_literal: true

require 'securerandom'

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

    # Applies BrowserManager#user_agent_override (Ferrum option
    # :user_agent_override) to every target before it runs. Ferrum resumes new
    # pages and out-of-process iframes (Turnstile) as soon as they attach, and
    # only prepares their Page when the code asks for it: the override is sent
    # from an attach handler registered before Ferrum's, and commands on a
    # session run in order. Dedicated workers inherit it from their page.
    module MaskedUserAgentTargets
      WORKER_TYPES = %w[service_worker shared_worker].freeze

      private

      def subscribe
        @client.on('Target.attachedToTarget') { |params| mask_user_agent(params) }
        super
      end

      def mask_user_agent(params)
        override = @client.options.to_h[:user_agent_override]
        type = params.dig('targetInfo', 'type')
        return unless override

        method = if WORKER_TYPES.include?(type) then 'Network.setUserAgentOverride'
                 elsif Ferrum::Contexts::ALLOWED_TARGET_TYPES.include?(type) then 'Emulation.setUserAgentOverride'
                 end
        @client.session(params['sessionId']).command(method, async: true, **override) if method
      end
    end

    # Pages Ferrum attaches to itself (Chrome's startup tab) never go through
    # Target.attachedToTarget.
    module MaskedUserAgentPage
      private

      def prepare_page
        override = @options.to_h[:user_agent_override]
        command('Emulation.setUserAgentOverride', **override) if override
        super
      end
    end

    # Ferrum enables the Runtime domain on every page to learn the execution
    # context of each frame. With Runtime enabled, Chrome serializes every
    # console.* argument for the client, reading getters (an error's stack or
    # name) a plain browser never reads: anti-bot scripts (brotector) detect
    # automation that way.
    # Runtime stays disabled; a frame's main-world context is looked up on
    # demand, the rebrowser-patches way: an isolated world dispatches a DOM
    # event, a listener installed in the main world answers through a CDP
    # binding, and Runtime.bindingCalled carries the main world's context id.
    # Without Runtime enabled, Chrome only installs a binding and runs a
    # new-document script in the documents that exist when they are added, so
    # both are added at each lookup.
    module HiddenRuntimePage
      CONTEXT_LOOKUP_TIMEOUT = 2

      def command(method, **params)
        return {} if method == 'Runtime.enable' && FerrumPatches.hide_runtime?

        super
      rescue Ferrum::NoExecutionContextError
        forget_execution_context(params[:executionContextId])
        raise
      end

      # Main-world execution context id of a frame of this page.
      def main_world_context_id(frame)
        install_context_lookup
        frame_id = frame.id || @main_frame.id
        answer = Queue.new
        @context_lookups[frame_id] = answer
        install_context_lookup_listener
        world = command('Page.createIsolatedWorld', frameId: frame_id, worldName: @context_lookup_name,
                                                    grantUniveralAccess: true)['executionContextId']
        command('Runtime.evaluate', contextId: world, expression: <<~JS)
          document.dispatchEvent(new CustomEvent('#{@context_lookup_name}', { detail: '#{frame_id}' }))
        JS
        # A document without the listener only has the isolated world: the DOM
        # is there, not the page's globals.
        answer.pop(timeout: CONTEXT_LOOKUP_TIMEOUT) || world
      ensure
        @context_lookups&.delete(frame_id)
      end

      private

      def prepare_page
        super
        install_context_lookup if FerrumPatches.hide_runtime?
      end

      # Idempotent: prepare_page may already need a context (extensions).
      def install_context_lookup
        return if @context_lookup_name

        @context_lookup_name = "_#{SecureRandom.alphanumeric(12)}"
        @context_lookups = Concurrent::Map.new
        register_frames
        on('Runtime.bindingCalled') do |params|
          next unless params['name'] == @context_lookup_name

          @context_lookups[params['payload']]&.push(params['executionContextId'])
        end
        # A new document gets a new context: forget the old one.
        on('Page.frameNavigated') { |params| @frames[params.dig('frame', 'id')]&.execution_id = nil }
      end

      # Runs the listener in every current document, then drops the script so
      # future documents stay untouched.
      def install_context_lookup_listener
        command('Runtime.addBinding', name: @context_lookup_name)
        script = command('Page.addScriptToEvaluateOnNewDocument', source: context_lookup_listener,
                                                                  runImmediately: true)['identifier']
        command('Page.removeScriptToEvaluateOnNewDocument', identifier: script)
      end

      # The listener keeps the binding and removes it from the page's globals.
      def context_lookup_listener
        name = @context_lookup_name
        <<~JS
          (() => {
            const answer = self['#{name}'];
            if (typeof answer !== 'function') return;
            delete self['#{name}'];
            document.addEventListener('#{name}', (event) => {
              event.stopImmediatePropagation();
              answer(String(event.detail));
            }, true);
          })();
        JS
      end

      # Ferrum registered the frames already there (a popup's iframes, loaded
      # before the code picks the popup up) from Runtime.executionContextCreated.
      # They are registered as loaded: navigations wait for every frame to stop
      # loading. Out-of-process iframes (New Tab page, Turnstile) are separate
      # targets whose loading this page never hears about; Ferrum left them out.
      def register_frames
        tree = command('Page.getFrameTree')['frameTree']
        @main_frame.id ||= tree.dig('frame', 'id')
        @frames.put_if_absent(@main_frame.id, @main_frame)
        out_of_process = out_of_process_frame_ids
        FrameTree.flatten(tree).drop(1).each do |info|
          next if out_of_process.include?(info['id'])

          frame = Ferrum::Frame.new(info['id'], self, info['parentId'])
          frame.name = info['name']
          frame.state = :stopped_loading
          @frames.put_if_absent(info['id'], frame)
        end
      end

      # An out-of-process iframe is a target whose id is its frame id.
      def out_of_process_frame_ids
        command('Target.getTargets')['targetInfos'].filter_map { |t| t['targetId'] if t['type'] == 'iframe' }
      end

      def forget_execution_context(context_id)
        return unless context_id

        frames.each { |frame| frame.execution_id = nil if frame.execution_id == context_id }
      end
    end

    module HiddenRuntimeFrame
      def execution_id!
        return super unless FerrumPatches.hide_runtime?

        execution_id || @page.main_world_context_id(self).tap { |id| self.execution_id = id }
      end
    end

    # FERRUM_RUNTIME_ENABLE=true restores Ferrum's behaviour (Runtime enabled).
    def self.hide_runtime?
      ENV['FERRUM_RUNTIME_ENABLE'] != 'true'
    end

    def self.apply!
      return if Ferrum::Contexts.include?(ResumeBackgroundTargets)

      Ferrum::Contexts.prepend(ResumeBackgroundTargets)
      Ferrum::Contexts.prepend(MaskedUserAgentTargets)
      Ferrum::Page.prepend(HiddenRuntimePage)
      Ferrum::Page.prepend(MaskedUserAgentPage)
      Ferrum::Frame.prepend(HiddenRuntimeFrame)
    end
  end
end
