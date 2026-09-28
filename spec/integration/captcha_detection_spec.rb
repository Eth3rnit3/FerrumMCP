# frozen_string_literal: true

require 'spec_helper'

# Ferrum drives Chrome's own startup tab (see BrowserManager). Frames left over
# from the New Tab page never get an execution context, and Ferrum's
# Frame#url evaluates JavaScript: detection waited on them for minutes.
RSpec.describe 'CAPTCHA detection' do
  let(:session_manager) { FerrumMCP::SessionManager.new(FerrumMCP::Configuration.new) }

  after { session_manager.shutdown }

  it 'inspects the frames of a page without hanging' do
    sid = session_manager.create_session(headless: true)

    elapsed = session_manager.with_session(sid) do |bm|
      bm.page.go_to(test_url('/fixtures/captcha/with_iframe'))
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      Timeout.timeout(20) { FerrumMCP::Captcha::Detector.detect(bm.page) }
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    end

    expect(elapsed).to be < 3
  end
end
