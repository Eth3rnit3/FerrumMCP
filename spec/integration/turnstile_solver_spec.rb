# frozen_string_literal: true

require 'spec_helper'

# Cloudflare pages imitated by fixtures: the solver is driven directly on the
# session's page, since the fixtures cannot load the real Turnstile frame.
RSpec.describe FerrumMCP::Captcha::TurnstileSolver do
  let(:session_manager) { FerrumMCP::SessionManager.new(FerrumMCP::Configuration.new) }

  after { session_manager.shutdown }

  def solve(fixture, **options)
    sid = setup_session_with_fixture(session_manager, fixture, subdir: 'captcha')
    session_manager.with_session(sid) do |bm|
      described_class.new(bm.page, logger: Logger.new(File::NULL), **options).solve
    end
  end

  # The interstitial used to count as passed as soon as its title changed,
  # including when Cloudflare replaced it with "Sorry, you have been blocked".
  it 'reports the Cloudflare block page as blocked, not solved' do
    result = solve('turnstile_blocked.html', max_attempts: 1)

    expect(result.solved?).to be false
    expect(result.status).to eq(:blocked)
    expect(result.message).to match(/blocked/i)
  end

  # Invisible mode renders no widget: the token lands in the hidden input
  # while the solver waits for a checkbox that never comes.
  it 'picks up the token of an invisible widget without a click' do
    result = solve('turnstile_invisible.html', max_attempts: 1)

    expect(result.solved?).to be true
    expect(result.token).to start_with('0.invisible-token-')
    expect(result.attempts).to eq(0)
  end
end
