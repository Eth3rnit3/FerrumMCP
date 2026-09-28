# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FerrumMCP::Captcha::RecaptchaSolver do
  # Clients reCAPTCHA distrusts get unintelligible audio. Whisper then invents
  # a stock phrase ("see you next time") or hears another language, and
  # submitting that answer only lowers the IP's reputation.
  describe '.garbled?' do
    def transcription(text, language: 'en', probability: 0.99)
      FerrumMCP::WhisperService::Transcription.new(text: text, language: language, language_probability: probability)
    end

    it 'accepts clear speech in the expected language' do
      expect(described_class.garbled?(transcription('please turn the lights off'), 'en')).to be false
    end

    it 'flags audio detected in another language' do
      expect(described_class.garbled?(transcription('gracias por ver el video', language: 'es'), 'en')).to be true
    end

    it 'flags whisper stock hallucinations even in the expected language' do
      ['see you next time', 'thanks for watching', "i'm not sure i'm not sure", ''].each do |text|
        expect(described_class.garbled?(transcription(text), 'en')).to be(true), text
      end
    end

    it 'does not check the language when it is set to auto' do
      expect(described_class.garbled?(transcription('ouvrez la porte', language: 'fr'), 'auto')).to be false
    end
  end
end
