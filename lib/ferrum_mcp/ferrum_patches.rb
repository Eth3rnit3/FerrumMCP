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
        register_main_frame
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

      # Ferrum registered the main frame from Runtime.executionContextCreated.
      # Child frames come from Page.frameAttached; registering the current
      # ones would include out-of-process iframes (New Tab page) that never
      # report their loading state here, and navigations would wait for them.
      def register_main_frame
        @main_frame.id ||= command('Page.getFrameTree').dig('frameTree', 'frame', 'id')
        @frames.put_if_absent(@main_frame.id, @main_frame)
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
      Ferrum::Page.prepend(HiddenRuntimePage)
      Ferrum::Frame.prepend(HiddenRuntimeFrame)
    end
  end
end
