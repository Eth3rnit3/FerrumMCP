# frozen_string_literal: true

require 'spec_helper'
require 'vips'

RSpec.describe FerrumMCP::Tools::ScreenshotTool do
  let(:config) { FerrumMCP::Configuration.new }
  let(:session_manager) { FerrumMCP::SessionManager.new(config) }
  let(:screenshot_tool) do
    sid = session_manager.create_session(headless: true)
    session_manager.with_session(sid) do |browser_manager|
      described_class.new(browser_manager)
    end
  end

  after do
    session_manager.shutdown
  end

  describe '#resize_if_needed' do
    let(:small_image_data) { create_test_image(800, 600) }
    let(:wide_image_data) { create_test_image(10_000, 600) }
    let(:tall_image_data) { create_test_image(800, 10_000) }
    let(:huge_image_data) { create_test_image(12_000, 9_000) }

    it 'does not resize images within limits' do
      result = screenshot_tool.send(:resize_if_needed, small_image_data, 'png')
      image = Vips::Image.new_from_buffer(result, '')

      expect(image.width).to eq(800)
      expect(image.height).to eq(600)
    end

    it 'resizes wide images exceeding width limit' do
      result = screenshot_tool.send(:resize_if_needed, wide_image_data, 'png')
      image = Vips::Image.new_from_buffer(result, '')

      expect(image.width).to eq(8000)
      expect(image.height).to be <= 8000
      # Check aspect ratio is preserved (within 1% tolerance)
      original_ratio = 10_000.0 / 600
      new_ratio = image.width.to_f / image.height
      expect(new_ratio).to be_within(original_ratio * 0.01).of(original_ratio)
    end

    it 'resizes tall images exceeding height limit' do
      result = screenshot_tool.send(:resize_if_needed, tall_image_data, 'png')
      image = Vips::Image.new_from_buffer(result, '')

      expect(image.height).to eq(8000)
      expect(image.width).to be <= 8000
      # Check aspect ratio is preserved (within 1% tolerance)
      original_ratio = 800.0 / 10_000
      new_ratio = image.width.to_f / image.height
      expect(new_ratio).to be_within(original_ratio * 0.01).of(original_ratio)
    end

    it 'resizes images exceeding both dimensions' do
      result = screenshot_tool.send(:resize_if_needed, huge_image_data, 'png')
      image = Vips::Image.new_from_buffer(result, '')

      expect(image.width).to be <= 8000
      expect(image.height).to be <= 8000
      # The limiting dimension should be exactly 8000
      expect([image.width, image.height].max).to eq(8000)
      # Check aspect ratio is preserved (within 1% tolerance)
      original_ratio = 12_000.0 / 9_000
      new_ratio = image.width.to_f / image.height
      expect(new_ratio).to be_within(original_ratio * 0.01).of(original_ratio)
    end

    it 'preserves format when resizing' do
      jpeg_data = create_test_image(10_000, 600, 'jpg')
      result = screenshot_tool.send(:resize_if_needed, jpeg_data, 'jpeg')
      image = Vips::Image.new_from_buffer(result, '')

      expect(image.get('vips-loader')).to match(/jpeg/i)
    end
  end

  # Helper method to create test images using Vips
  def create_test_image(width, height, format = 'png')
    # Create a white image
    image = Vips::Image.black(width, height, bands: 3) + 255
    image.write_to_buffer(".#{format}")
  end
end
