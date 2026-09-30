# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FerrumMCP::Captcha::BaseSolver do
  let(:moves) { [] }
  let(:mouse) { instance_double(Ferrum::Mouse) }
  let(:page) { instance_double(Ferrum::Page, mouse: mouse, command: nil) }
  let(:solver) { described_class.new(page, logger: Logger.new(File::NULL)) }

  before do
    allow(page).to receive(:evaluate).with('[window.innerWidth, window.innerHeight]').and_return([1280, 800])
    allow(solver).to receive(:sleep)
    allow(mouse).to receive(:move) { |x:, y:| moves << [x, y] }
  end

  describe '#wait_until' do
    it 'treats errors raised while the widget re-renders as "not yet"' do
      calls = 0
      value = solver.send(:wait_until, 1) do
        calls += 1
        raise Ferrum::NodeNotFoundError, 'detached' if calls == 1

        :ready
      end

      expect(value).to eq(:ready)
    end

    # The session marks its browser dead on this error; polling on it for the
    # whole timeout would hide it.
    it 'lets a dead browser error through immediately' do
      expect do
        solver.send(:wait_until, 5) { raise Ferrum::DeadBrowserError }
      end.to raise_error(Ferrum::DeadBrowserError)
      expect(solver).not_to have_received(:sleep)
    end
  end

  # reCAPTCHA watches the pointer on the whole page before the click; a bot
  # that appears on the checkbox from nowhere gets the decoy audio.
  describe '#warm_up' do
    it 'wanders over the page before acting' do
      solver.send(:warm_up, 3)

      expect(moves.size).to be >= 40
      expect(moves.map(&:first)).to all(be_between(0, 1280))
      expect(moves.map(&:last)).to all(be_between(0, 800))
      expect(moves.uniq.size).to be > 20
    end

    it 'scrolls a little with the mouse wheel' do
      allow(solver).to receive(:rand).and_call_original
      solver.send(:warm_up, 6)

      expect(page).to have_received(:command).with('Input.dispatchMouseEvent', hash_including(type: 'mouseWheel'))
                                             .at_least(:once)
    end
  end
end
