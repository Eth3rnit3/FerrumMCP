# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FerrumMCP::Tools::FindByTextTool do
  let(:config) { FerrumMCP::Configuration.new }
  let(:sid) { setup_session_with_fixture(session_manager, 'find_by_text.html', subdir: 'extraction') }
  let(:session_manager) { FerrumMCP::SessionManager.new(config) }

  after { session_manager.shutdown }

  def run_tool(sid, params)
    session_manager.with_session(sid) { |bm| described_class.new(bm).execute(params.merge(session_id: sid)) }
  end

  # Number of elements a CSS selector matches, and the text of the first one
  def css_matches(sid, selector)
    session_manager.with_session(sid) do |bm|
      bm.page.evaluate("[document.querySelectorAll(#{selector.to_json}).length, " \
                       "(document.querySelector(#{selector.to_json}) || {}).textContent]")
    end
  end

  it 'returns the innermost element holding the text, not <html>' do
    result = run_tool(sid, text: 'Thermos isotherme 1 L')

    expect(result[:success]).to be true
    expect(result[:data][:tag]).to eq('span')
    expect(result[:data][:text]).to eq('Thermos isotherme 1 L robuste')
  end

  it 'ignores text that only appears inside scripts' do
    result = run_tool(sid, text: 'OnlyInScript')

    expect(result[:success]).to be false
  end

  it 'returns a selector that matches only the found element' do
    result = run_tool(sid, text: 'Rouge', exact: true)

    count, text = css_matches(sid, result[:data][:selector])
    expect(count).to eq(1)
    expect(text).to eq('Rouge')
  end

  it 'returns a ref other tools accept' do
    result = run_tool(sid, text: 'Doré', exact: true)
    ref = result[:data][:ref]

    count, text = css_matches(sid, "[data-fmcp-ref=\"#{ref.delete_prefix('ref:')}\"]")
    expect(ref).to match(/\Aref:e\d+\z/)
    expect([count, text]).to eq([1, 'Doré'])
  end

  it 'truncates long texts' do
    result = run_tool(sid, text: 'needle')

    expect(result[:data][:tag]).to eq('p')
    expect(result[:data][:text].length).to be <= 203
  end

  it 'lists every innermost match with unique selectors' do
    result = run_tool(sid, text: 'acier', multiple: true)

    elements = result[:data][:elements]
    expect(elements.map { |e| e[:text] }).to eq(['Gourde en acier', 'Acier'])
    expect(elements.map { |e| css_matches(sid, e[:selector]).first }).to eq([1, 1])
  end
end
