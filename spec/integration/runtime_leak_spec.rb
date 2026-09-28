# frozen_string_literal: true

require 'spec_helper'

# Ferrum enables the CDP Runtime domain on every page. Chrome then serializes
# every console.* argument for the client, reading getters a real browser never
# touches: pages (brotector, anti-bot scripts) detect automation that way.
RSpec.describe 'Runtime domain leak' do
  let(:session_manager) { FerrumMCP::SessionManager.new(FerrumMCP::Configuration.new) }
  let(:sid) { session_manager.create_session(headless: true) }

  after { session_manager.shutdown }

  def on_page(path)
    session_manager.with_session(sid) do |bm|
      bm.page.go_to(test_url(path))
      yield bm.page
    end
  end

  it 'does not let the page detect a DevTools client through console serialization' do
    detected = on_page('/fixtures/stealth/cdp_console_probe') do |page|
      sleep 0.4
      page.evaluate('window.cdpDetected')
    end

    expect(detected).to be false
  end

  it 'still evaluates in the page main world' do
    value = on_page('/fixtures/stealth/cdp_console_probe') { |page| page.evaluate('window.pageGlobal') }

    expect(value).to eq('main-world')
  end

  it 'still evaluates inside a child frame' do
    value = on_page('/fixtures/stealth/cdp_console_probe') do |page|
      page.at_css('#child')
      frame = page.frame_by(name: 'child')
      frame.evaluate("document.getElementById('inner').textContent + ':' + window.childGlobal")
    end

    expect(value).to eq('inside:child')
  end

  it 'evaluates in the new document after a navigation' do
    titles = session_manager.with_session(sid) do |bm|
      bm.page.go_to(test_url('/fixtures/stealth/cdp_console_probe'))
      first = bm.page.evaluate('document.title')
      bm.page.go_to(test_url('/test'))
      [first, bm.page.evaluate('document.title')]
    end

    expect(titles.first).to eq('CDP console probe')
    expect(titles.last).not_to eq('CDP console probe')
  end
end
