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
end
