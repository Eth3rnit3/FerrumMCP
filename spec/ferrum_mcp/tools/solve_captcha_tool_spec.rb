# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FerrumMCP::Tools::SolveCaptchaTool do
  let(:config) { FerrumMCP::Configuration.new }
  let(:session_manager) { FerrumMCP::SessionManager.new(config) }

  after { session_manager.shutdown }

  def run_tool(sid, params = {})
    session_manager.with_session(sid) { |bm| described_class.new(bm).execute(params.merge(session_id: sid)) }
  end

  def evaluate(sid, expression)
    session_manager.with_session(sid) { |bm| bm.page.evaluate(expression) }
  end

  context 'when the page has no supported CAPTCHA widget' do
    it 'reports that nothing was solved and leaves the host page untouched' do
      sid = setup_session_with_fixture(session_manager, 'fake_audio_challenge.html', subdir: 'captcha')

      result = run_tool(sid)

      expect(result[:success]).to be false
      expect(result[:error]).to match(/no supported captcha/i)
      expect(evaluate(sid, 'window.hostSubmitted')).to be false
      expect(evaluate(sid, "document.querySelector('#username').value")).to eq('')
    end
  end

  # The fixtures cannot load Cloudflare's frame, so detection is stubbed and
  # the Turnstile solver runs against the imitated block page.
  context 'when the CAPTCHA cannot be solved' do
    before { allow(FerrumMCP::Captcha::Detector).to receive(:detect).and_return([:turnstile]) }

    it 'attaches a screenshot so the agent can see what happened' do
      sid = setup_session_with_fixture(session_manager, 'turnstile_blocked.html', subdir: 'captcha')

      result = run_tool(sid, max_attempts: 1)

      expect(result[:success]).to be false
      expect(result[:error]).to include('turnstile, blocked')
      expect(result[:image]).to match(/\A[A-Za-z0-9+\/=]{100,}\z/) # base64 PNG
    end

    it 'skips the screenshot when asked to' do
      sid = setup_session_with_fixture(session_manager, 'turnstile_blocked.html', subdir: 'captcha')

      result = run_tool(sid, max_attempts: 1, screenshot_on_failure: false)

      expect(result[:success]).to be false
      expect(result).not_to have_key(:image)
    end
  end
end
