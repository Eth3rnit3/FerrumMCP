# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FerrumMCP::WhisperService do
  describe '.clean' do
    it 'lowercases and strips punctuation the way CAPTCHA inputs expect' do
      expect(described_class.clean(" See you, next time!\n")).to eq('see you next time')
    end

    it 'drops whisper annotations' do
      expect(described_class.clean('[BLANK_AUDIO]')).to eq('')
      expect(described_class.clean('(music) add the tofu [Laughter] sauce')).to eq('add the tofu sauce')
    end

    it 'keeps digits, apostrophes and accented letters' do
      expect(described_class.clean("Don't open door 42, café.")).to eq("don't open door 42 café")
    end
  end

  describe '#model_path' do
    it 'resolves model names inside the whisper.cpp models directory' do
      expect(described_class.new(model: 'base.en').model_path).to end_with('/.whisper.cpp/models/ggml-base.en.bin')
    end

    it 'accepts an explicit .bin path' do
      expect(described_class.new(model: '/opt/models/custom.bin').model_path).to eq('/opt/models/custom.bin')
    end
  end

  describe '#ensure_ready!' do
    it 'explains how to install whisper-cli when it is missing' do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with('WHISPER_PATH', 'whisper-cli').and_return('/nonexistent/whisper-cli')

      expect { described_class.new.ensure_ready! }.to raise_error(FerrumMCP::ToolError, /whisper-cli not found/)
    end

    it 'rejects unknown model names before downloading anything' do
      service = described_class.new(model: 'gigantic')
      allow(service).to receive(:available?).and_return(true)

      expect { service.ensure_ready! }.to raise_error(FerrumMCP::ToolError, /Unknown Whisper model/)
    end
  end
end
