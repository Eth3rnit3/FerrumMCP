# frozen_string_literal: true

require 'spec_helper'

# Headless Chrome announces "HeadlessChrome" in its user agent. Replacing it
# with the --user-agent flag also empties the high-entropy client hints
# (full version, platform version, architecture), which no stock Chrome
# reports: brotector flags that as a user agent override.
RSpec.describe 'Headless user agent' do
  let(:session_manager) { FerrumMCP::SessionManager.new(FerrumMCP::Configuration.new) }
  let(:probe) do
    sid = session_manager.create_session(headless: true)
    session_manager.with_session(sid) do |bm|
      bm.page.go_to(test_url('/fixtures/stealth/user_agent_probe'))
      bm.page.evaluate_async('window.uaProbe.then(arguments[0])', 5)
    end
  end

  after { session_manager.shutdown }

  %w[page worker].each do |scope|
    it "hides headless from the #{scope}" do
      expect(probe[scope]['userAgent']).to include('Chrome/')
      expect(probe[scope]['userAgent']).not_to include('Headless')
      expect(probe[scope]['brands'].join(' ')).not_to include('Headless')
    end

    it "keeps the #{scope}'s high-entropy client hints" do
      expect(probe[scope]['uaFullVersion']).to match(/\A\d+\.\d+\.\d+\.\d+\z/)
      expect(probe[scope]['architecture']).not_to be_empty
    end
  end
end
