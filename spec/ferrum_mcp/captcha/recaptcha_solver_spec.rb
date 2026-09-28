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

  describe 'audio rounds against a distrusting reCAPTCHA' do
    let(:decoy) { FerrumMCP::WhisperService::Transcription.new(text: 'see you next time', language: 'es') }
    let(:solver) { described_class.new(instance_double(Ferrum::Page), logger: Logger.new(File::NULL), max_attempts: 5) }

    before do
      allow(solver).to receive_messages(current_challenge: 'audio', checked?: false, audio_source: 'https://x/payload')
      allow(solver).to receive(:transcribe).and_return(decoy)
      allow(solver).to receive(:reload_challenge)
      allow(solver).to receive(:submit_answer)
    end

    # Reloading the decoy over and over gets the IP blocked by Google
    it 'gives up after two garbled audios in a row without answering them' do
      result = solver.send(:solve_audio_rounds)

      expect(result.status).to eq(:distrusted)
      expect(result.attempts).to eq(2)
      expect(solver).to have_received(:reload_challenge).once
      expect(solver).not_to have_received(:submit_answer)
    end
  end

  describe 'downloading the challenge audio' do
    let(:frame) { instance_double(Ferrum::Frame) }
    let(:transcriber) { instance_double(FerrumMCP::WhisperService) }
    let(:solver) do
      described_class.new(instance_double(Ferrum::Page), logger: Logger.new(File::NULL), transcriber: transcriber)
    end
    let(:heard) { FerrumMCP::WhisperService::Transcription.new(text: 'hello world', language: 'en') }

    before do
      allow(solver).to receive(:challenge_frame).and_return(frame)
      allow(solver).to receive(:sleep)
      allow(transcriber).to receive(:analyze_bytes).and_return(heard)
    end

    # Fetched right after the challenge appears, the audio came back cut at
    # 8 KB: whisper heard nothing and the only real challenge was discarded.
    it 'downloads again when the audio is truncated' do
      truncated = Base64.strict_encode64('a' * 8192)
      full = Base64.strict_encode64('a' * 30_000)
      allow(frame).to receive(:evaluate_async).and_return(truncated, full)

      solver.send(:transcribe, 'https://www.google.com/recaptcha/api2/payload?p=x')

      expect(transcriber).to have_received(:analyze_bytes).with('a' * 30_000)
    end

    it 'uses the largest download when it stays small' do
      allow(frame).to receive(:evaluate_async).and_return(*[4000, 9000, 6000].map do |n|
        Base64.strict_encode64('a' * n)
      end)

      solver.send(:transcribe, 'https://www.google.com/recaptcha/api2/payload?p=x')

      expect(transcriber).to have_received(:analyze_bytes).with('a' * 9000)
    end
  end
end
