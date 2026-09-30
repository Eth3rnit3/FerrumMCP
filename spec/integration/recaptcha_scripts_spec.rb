# frozen_string_literal: true

require 'spec_helper'

# The host-page scripts of RecaptchaSolver, run against fixtures imitating
# reCAPTCHA's markup.
RSpec.describe 'reCAPTCHA host-page scripts' do
  let(:session_manager) { FerrumMCP::SessionManager.new(FerrumMCP::Configuration.new) }

  after { session_manager.shutdown }

  def evaluate_on(fixture, script, *args)
    sid = setup_session_with_fixture(session_manager, fixture, subdir: 'captcha')
    session_manager.with_session(sid) { |bm| bm.page.evaluate(script, *args) }
  end

  # Sites integrating through the JS callback have no g-recaptcha-response
  # textarea: the token is only reachable through grecaptcha.getResponse().
  it 'reads the token through the grecaptcha API when the page has no response textarea' do
    token = evaluate_on('recaptcha_callback_only.html', FerrumMCP::Captcha::RecaptchaScripts::TOKEN_JS, 'a-abc123')

    expect(token).to start_with('enterprise-token-')
  end
end
