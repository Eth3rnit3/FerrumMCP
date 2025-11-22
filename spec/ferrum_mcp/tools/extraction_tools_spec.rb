# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Extraction Tools' do
  let(:config) { FerrumMCP::Configuration.new }
  let(:session_manager) { FerrumMCP::SessionManager.new(config) }

  after do
    session_manager.shutdown
  end

  # Helper to execute tool within session context
  def execute_tool_in_session(tool_class, session_id, params)
    session_manager.with_session(session_id) do |browser_manager|
      tool = tool_class.new(browser_manager)
      tool.execute(params)
    end
  end

  describe FerrumMCP::Tools::GetTextTool do
    describe '.tool_name' do
      it 'returns get_text' do
        expect(described_class.tool_name).to eq('get_text')
      end
    end

    describe '#execute' do
      it 'gets text from a single element' do
        sid = setup_session_with_fixture(session_manager, 'content_page.html', subdir: 'extraction')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, selector: '#main-title' }
        )

        expect(result[:success]).to be true
        expect(result[:data][:text]).to eq('Content Extraction Test Page')
      end

      it 'gets text from multiple elements' do
        sid = setup_session_with_fixture(session_manager, 'content_page.html', subdir: 'extraction')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, selector: '.paragraph', multiple: true }
        )

        expect(result[:success]).to be true
        expect(result[:data][:texts]).to be_an(Array)
        expect(result[:data][:count]).to eq(3)
        expect(result[:data][:texts].first).to include('first paragraph')
      end

      it 'returns error when element not found' do
        sid = setup_session_with_fixture(session_manager, 'content_page.html', subdir: 'extraction')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, selector: '#non-existent' }
        )

        expect(result[:success]).to be false
        expect(result[:error]).to include('Element not found')
      end
    end
  end

  describe FerrumMCP::Tools::GetHTMLTool do
    describe '.tool_name' do
      it 'returns get_html' do
        expect(described_class.tool_name).to eq('get_html')
      end
    end

    describe '#execute' do
      it 'gets HTML of a specific element' do
        sid = setup_session_with_fixture(session_manager, 'content_page.html', subdir: 'extraction')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, selector: '#html-content' }
        )

        expect(result[:success]).to be true
        expect(result[:data][:html]).to include('<strong>Bold text</strong>')
        expect(result[:data][:html]).to include('<em>Italic text</em>')
        expect(result[:data][:selector]).to eq('#html-content')
      end

      it 'gets full page HTML when no selector provided' do
        sid = setup_session_with_fixture(session_manager, 'content_page.html', subdir: 'extraction')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid }
        )

        expect(result[:success]).to be true
        expect(result[:data][:html]).to include('<html')
        expect(result[:data][:html]).to include('Content Extraction Test Page')
        expect(result[:data][:url]).to include('/fixtures/extraction/content_page')
      end
    end
  end

  describe FerrumMCP::Tools::ScreenshotTool do
    describe '.tool_name' do
      it 'returns screenshot' do
        expect(described_class.tool_name).to eq('screenshot')
      end
    end

    describe '#execute' do
      it 'takes a PNG screenshot' do
        sid = setup_session_with_fixture(session_manager, 'content_page.html', subdir: 'extraction')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, format: 'png' }
        )

        expect(result[:success]).to be true
        expect(result[:type]).to eq('image')
        expect(result[:data]).to be_a(String)
        expect(result[:mime_type]).to eq('image/png')

        # Verify it's valid base64
        expect { Base64.decode64(result[:data]) }.not_to raise_error
      end

      it 'takes a JPEG screenshot' do
        sid = setup_session_with_fixture(session_manager, 'content_page.html', subdir: 'extraction')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, format: 'jpeg' }
        )

        expect(result[:success]).to be true
        expect(result[:mime_type]).to eq('image/jpeg')
      end

      it 'takes a full page screenshot' do
        sid = setup_session_with_fixture(session_manager, 'content_page.html', subdir: 'extraction')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, full_page: true }
        )

        expect(result[:success]).to be true
        expect(result[:data]).to be_a(String)
      end

      it 'takes screenshot of specific element' do
        sid = setup_session_with_fixture(session_manager, 'content_page.html', subdir: 'extraction')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, selector: '#main-title' }
        )

        expect(result[:success]).to be true
        expect(result[:data]).to be_a(String)
      end

      it 'resizes screenshots that exceed Claude API dimension limits' do
        sid = setup_session_with_fixture(session_manager, 'content_page.html', subdir: 'extraction')

        # Take a full page screenshot which may exceed limits
        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid, format: 'png', full_page: true }
        )

        expect(result[:success]).to be true
        expect(result[:data]).to be_a(String)

        # Decode the base64 image and verify dimensions
        require 'vips'
        image_data = Base64.decode64(result[:data])
        image = Vips::Image.new_from_buffer(image_data, '')

        # Verify neither dimension exceeds the max limit
        max_dim = FerrumMCP::Tools::ScreenshotTool::MAX_DIMENSION
        expect(image.width).to be <= max_dim
        expect(image.height).to be <= max_dim
      end
    end
  end

  describe FerrumMCP::Tools::GetTitleTool do
    describe '.tool_name' do
      it 'returns get_title' do
        expect(described_class.tool_name).to eq('get_title')
      end
    end

    describe '#execute' do
      it 'gets page title' do
        sid = setup_session_with_fixture(session_manager, 'content_page.html', subdir: 'extraction')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid }
        )

        expect(result[:success]).to be true
        expect(result[:data][:title]).to eq('Content Extraction Test')
        expect(result[:data][:url]).to include('/fixtures/extraction/content_page')
      end
    end
  end

  describe FerrumMCP::Tools::GetURLTool do
    describe '.tool_name' do
      it 'returns get_url' do
        expect(described_class.tool_name).to eq('get_url')
      end
    end

    describe '#execute' do
      it 'gets current URL' do
        sid = setup_session_with_fixture(session_manager, 'content_page.html', subdir: 'extraction')

        result = execute_tool_in_session(
          described_class,
          sid,
          { session_id: sid }
        )

        expect(result[:success]).to be true
        expect(result[:data][:url]).to include('/fixtures/extraction/content_page')
      end
    end
  end
end
