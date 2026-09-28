# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FerrumMCP::Tools::SnapshotTool do
  let(:config) { FerrumMCP::Configuration.new }
  let(:session_manager) { FerrumMCP::SessionManager.new(config) }

  after { session_manager.shutdown }

  def run_tool(tool_class, sid, params = {})
    session_manager.with_session(sid) { |bm| tool_class.new(bm).execute(params.merge(session_id: sid)) }
  end

  it 'declares its interface' do
    expect(described_class.tool_name).to eq('snapshot')
    expect(described_class.input_schema[:required]).to eq(['session_id'])
  end

  it 'lists interactive elements with stable refs, roles and names' do
    sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

    result = run_tool(described_class, sid)

    expect(result[:success]).to be true
    text = result[:data][:snapshot]
    expect(text).to match(/\[e\d+\] link "Documentation" href=\/docs/)
    expect(text).to match(/\[e\d+\] button "Create account"/)
    expect(text).to match(/\[e\d+\] textbox "Email address".*placeholder="you@example.com"/)
    expect(text).to match(/\[e\d+\] checkbox "newsletter" checked/)
    expect(text).to match(/\[e\d+\] combobox "plan"/)
    expect(text).to match(/\[e\d+\] button "Custom role button"/)
    expect(text).to match(/\[e\d+\] button "Disabled action" disabled/)
    expect(text).to include('heading(1) "Agent Tools"')
    expect(text).not_to include('Hidden action')
    expect(result[:data][:url]).to include('agent_page')
    expect(result[:data][:count]).to be > 5
  end

  it 'returns structured elements in json format' do
    sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

    result = run_tool(described_class, sid, format: 'json')

    link = result[:data][:elements].find { |e| e[:name] == 'Documentation' }
    expect(link).to include(role: 'link', tag: 'a', ref: match(/\Ae\d+\z/))
    expect(link[:selector]).to eq('#docs-link')
  end

  it 'keeps the same ref for the same element across snapshots' do
    sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

    first = run_tool(described_class, sid, format: 'json')[:data][:elements]
    second = run_tool(described_class, sid, format: 'json')[:data][:elements]

    ref_of = ->(list) { list.find { |e| e[:name] == 'Create account' }[:ref] }
    expect(ref_of.call(second)).to eq(ref_of.call(first))
  end

  it 'lets other tools act on a ref' do
    sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')
    elements = run_tool(described_class, sid, format: 'json')[:data][:elements]
    ref = elements.find { |e| e[:name] == 'Custom role button' }[:ref]

    click = run_tool(FerrumMCP::Tools::ClickTool, sid, selector: "ref:#{ref}")
    status = run_tool(FerrumMCP::Tools::GetTextTool, sid, selector: '#status')

    expect(click[:success]).to be true
    expect(status[:data][:text]).to eq('custom-clicked')
  end

  it 'includes hidden elements on request and limits the output' do
    sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

    result = run_tool(described_class, sid, include_hidden: true, max_elements: 3)

    expect(result[:data][:truncated]).to be true
    expect(result[:data][:count]).to eq(3)
    full = run_tool(described_class, sid, include_hidden: true)
    expect(full[:data][:snapshot]).to include('Hidden action')
  end

  it 'scopes the snapshot to a selector' do
    sid = setup_session_with_fixture(session_manager, 'agent_page.html', subdir: 'agent')

    result = run_tool(described_class, sid, selector: 'nav')

    expect(result[:data][:snapshot]).to include('Documentation')
    expect(result[:data][:snapshot]).not_to include('Create account')
  end
end
