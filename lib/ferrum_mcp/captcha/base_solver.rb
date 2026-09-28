# frozen_string_literal: true

module FerrumMCP
  module Captcha
    # Shared plumbing for CAPTCHA solvers: frame lookup, polling and
    # human-looking mouse/keyboard input.
    #
    # All pointer input goes through CDP Input.dispatchMouseEvent at viewport
    # coordinates, so the events are trusted (isTrusted: true) and reach widgets
    # hidden behind closed shadow roots (Cloudflare Turnstile).
    class BaseSolver
      POLL_INTERVAL = 0.25

      attr_reader :page, :logger, :options

      def initialize(page, logger:, **options)
        @page = page
        @logger = logger
        @options = options
        @pointer = nil
      end

      # @return [Captcha::Result]
      def solve
        raise NotImplementedError
      end

      protected

      def type
        raise NotImplementedError
      end

      def unsolved(status, message, **details)
        Result.unsolved(type, status, message, **details)
      end

      def frames_matching(pattern)
        urls = Detector.frame_urls(page)
        page.frames.select { |frame| urls[frame.id].to_s.match?(pattern) }
      rescue StandardError => e
        logger.debug "Frame lookup failed: #{e.message}"
        []
      end

      # URL of a live frame without evaluating JavaScript (see Detector.frame_urls)
      def frame_url(frame)
        Detector.frame_urls(page)[frame.id].to_s
      end

      # Poll until the block returns a truthy value. Errors raised while the
      # widget re-renders (detached nodes, navigated frames) count as "not yet".
      def wait_until(timeout, interval: POLL_INTERVAL)
        deadline = monotonic_now + timeout
        loop do
          value = begin
            yield
          rescue StandardError => e
            logger.debug "wait_until: #{e.class}: #{e.message}"
            nil
          end
          return value if value
          return nil if monotonic_now > deadline

          sleep interval
        end
      end

      # Viewport box {x:, y:, width:, height:} of the <iframe> element that owns
      # a frame. Works through closed shadow roots since it goes through CDP.
      def frame_box(frame)
        owner = page.command('DOM.getFrameOwner', frameId: frame.id)
        node_box(owner['backendNodeId'])
      rescue StandardError => e
        logger.debug "frame_box failed: #{e.message}"
        nil
      end

      def node_box(backend_node_id)
        quad = page.command('DOM.getBoxModel', backendNodeId: backend_node_id)['model']['border']
        xs = quad.each_slice(2).map(&:first)
        ys = quad.each_slice(2).map(&:last)
        { x: xs.min, y: ys.min, width: xs.max - xs.min, height: ys.max - ys.min }
      rescue StandardError => e
        logger.debug "node_box failed: #{e.message}"
        nil
      end

      # Boxes of rendered <iframe> elements whose src matches, including
      # out-of-process frames that page.frames cannot see.
      def iframe_boxes(pattern)
        Detector.iframes(page)
                .select { |iframe| iframe[:src].match?(pattern) }
                .filter_map { |iframe| node_box(iframe[:backend_node_id]) }
                .select { |box| box[:width] > 1 && box[:height] > 1 }
      end

      def frame_visible?(frame)
        box = frame_box(frame)
        box && box[:width] > 1 && box[:height] > 1
      end

      # Scroll a node into view and click its centre with a human-looking move.
      def human_click_node(node)
        node.scroll_into_view
        pause(0.15, 0.35)
        x, y = node.find_position
        human_click(x + jitter(3), y + jitter(3))
      end

      def human_click(pos_x, pos_y)
        human_move(pos_x, pos_y)
        pause(0.05, 0.2)
        mouse_button(:mousePressed, pos_x, pos_y)
        sleep rand(0.06..0.14)
        mouse_button(:mouseReleased, pos_x, pos_y)
        pause(0.2, 0.45)
      end

      # Ferrum's Mouse#down sends force 0, so pointerdown fires with
      # pressure 0 while a button is held, which no real mouse does (the
      # Pointer Events spec mandates 0.5). Anti-bot scripts check for it.
      def mouse_button(type, pos_x, pos_y)
        page.command('Input.dispatchMouseEvent', type: type.to_s, x: pos_x, y: pos_y, button: 'left',
                                                 buttons: type == :mousePressed ? 1 : 0, clickCount: 1,
                                                 force: type == :mousePressed ? 0.5 : 0, pointerType: 'mouse')
      end

      # Move along a quadratic Bézier curve with ease-in-out timing, clamped to
      # the viewport when its size is known.
      def human_move(pos_x, pos_y)
        from = @pointer || [pos_x + rand(-260..-120), pos_y + rand(60..180)]
        control = [((from[0] + pos_x) / 2.0) + rand(-80..80), ((from[1] + pos_y) / 2.0) + rand(-80..80)]
        steps = rand(18..32)

        (1..steps).each do |i|
          point_x, point_y = clamp(bezier(from, control, [pos_x, pos_y], ease(i / steps.to_f)))
          page.mouse.move(x: point_x, y: point_y)
          sleep rand(0.006..0.02)
        end
        @pointer = [pos_x, pos_y]
      end

      # Behave like someone reading the page before acting: wander over it,
      # pause, scroll a bit and come back. reCAPTCHA watches the pointer on the
      # whole page, and a pointer that appears on the checkbox from nowhere
      # gets the decoy audio.
      def warm_up(seconds)
        @viewport = page.evaluate('[window.innerWidth, window.innerHeight]')
        width, height = @viewport
        (seconds / 0.8).ceil.times do
          human_move(rand((width * 0.1)..(width * 0.9)), rand((height * 0.1)..(height * 0.8)))
          pause(0.15, 0.7)
        end
        scroll_a_little(width, height) if seconds >= 4
      end

      # Type into a node one key at a time with irregular delays.
      def human_type(node, text)
        node.focus
        pause(0.1, 0.25)
        text.each_char do |char|
          node.type(char)
          sleep rand(0.04..0.16)
        end
      end

      def pause(min, max)
        sleep rand(min..max)
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      private

      def scroll_a_little(width, height)
        x = width / 2.0
        y = height / 2.0
        distance = rand(120..280)
        [distance, -distance].each do |delta|
          page.command('Input.dispatchMouseEvent', type: 'mouseWheel', x: x, y: y, deltaX: 0, deltaY: delta)
          pause(0.4, 1.0)
        end
      end

      def clamp(point)
        return point unless @viewport

        [point[0].clamp(0, @viewport[0]), point[1].clamp(0, @viewport[1])]
      end

      def jitter(amount)
        rand(-amount.to_f..amount.to_f)
      end

      def ease(progress)
        progress < 0.5 ? 2 * progress * progress : 1 - ((((-2 * progress) + 2)**2) / 2)
      end

      def bezier(start, control, finish, progress)
        inverse = 1 - progress
        [0, 1].map do |axis|
          ((inverse**2) * start[axis]) + (2 * inverse * progress * control[axis]) + ((progress**2) * finish[axis])
        end
      end
    end
  end
end
