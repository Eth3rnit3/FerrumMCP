# frozen_string_literal: true

require 'spec_helper'

# Ferrum auto-attaches to every new target with waitForDebuggerOnStart but only
# resumes pages and iframes: service workers, extension background pages and
# browser UI stayed paused forever. Sites relying on a service worker broke,
# and reCAPTCHA served its decoy audio even to a human driving the browser.
RSpec.describe 'Background targets' do
  let(:session_manager) { FerrumMCP::SessionManager.new(FerrumMCP::Configuration.new) }

  after { session_manager.shutdown }

  it 'lets a site service worker start' do
    sid = session_manager.create_session(headless: true)

    state = session_manager.with_session(sid) do |bm|
      bm.page.go_to(test_url('/sw/page'))
      deadline = Time.now + 5
      sleep 0.2 while bm.page.evaluate('window.swState') == 'pending' && Time.now < deadline
      bm.page.evaluate('window.swState')
    end

    expect(state).to eq('active')
  end
end
