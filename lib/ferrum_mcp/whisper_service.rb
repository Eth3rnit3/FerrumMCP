# frozen_string_literal: true

require 'tempfile'
require 'open3'
require 'fileutils'
require 'net/http'
require 'uri'

module FerrumMCP
  # Speech-to-text for audio CAPTCHAs, backed by whisper-cli (whisper.cpp).
  #
  # Audio is normalised to 16 kHz mono WAV with ffmpeg when it is available,
  # which is the format whisper.cpp is trained on and accepts on every build.
  class WhisperService
    # text: cleaned transcription; language: detected by the language-ID model
    Transcription = Struct.new(:text, :language, :language_probability, keyword_init: true)

    MODELS = %w[tiny tiny.en base base.en small small.en medium medium.en large-v3-turbo].freeze
    MODEL_BASE_URL = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main'
    MODELS_DIR = File.expand_path('~/.whisper.cpp/models')

    attr_reader :whisper_path, :ffmpeg_path, :model, :lid_model, :language, :logger

    # model: transcribes. lid_model: multilingual model used only to identify
    # the spoken language (english-only models cannot tell).
    def initialize(model: nil, lid_model: nil, language: nil, logger: nil)
      @whisper_path = ENV.fetch('WHISPER_PATH', 'whisper-cli')
      @ffmpeg_path = ENV.fetch('FFMPEG_PATH', 'ffmpeg')
      @model = model || ENV.fetch('WHISPER_MODEL', 'base.en')
      @lid_model = lid_model || ENV.fetch('WHISPER_LID_MODEL', 'small')
      @language = language || ENV.fetch('WHISPER_LANGUAGE', 'en')
      @logger = logger || Logger.new(File::NULL)
    end

    # Raise a ToolError explaining what is missing. Downloads the model if needed.
    def ensure_ready!
      verify_whisper_available!
      [model, lid_model].uniq.each { |name| ensure_model_available!(name) }
      self
    end

    def available?
      executable?(whisper_path)
    end

    # Identify the spoken language, then transcribe.
    # @return [Transcription]
    def analyze_bytes(bytes, extension: '.mp3')
      Tempfile.create(['captcha_audio', extension], binmode: true) do |file|
        file.write(bytes)
        file.flush
        with_wav(file.path) do |wav_path|
          detected, probability = detect_language(wav_path)
          Transcription.new(text: run_whisper(wav_path), language: detected, language_probability: probability)
        end
      end
    end

    # @param audio_path [String] path to an audio file
    # @return [String] cleaned transcription
    def transcribe(audio_path)
      with_wav(audio_path) { |wav_path| run_whisper(wav_path) }
    end

    # @return [Array(String, Float)] language code and probability, or [nil, nil]
    def detect_language(wav_path)
      _, stderr, status = Open3.capture3(whisper_path, '-m', model_path(lid_model), '-l', 'auto', '-dl', '-f', wav_path)
      match = stderr.match(/auto-detected language: (\w+) \(p = ([\d.]+)\)/)
      return [nil, nil] unless status.success? && match

      [match[1], match[2].to_f]
    end

    # Normalise a transcription into what CAPTCHA inputs expect: lowercase
    # words, no punctuation, no whisper annotations such as [BLANK_AUDIO].
    def self.clean(text)
      text.to_s
          .gsub(/\[[^\]]*\]|\([^)]*\)/, ' ')
          .downcase
          .gsub(/[^\p{L}\p{N}\s']/, ' ')
          .gsub(/\s+/, ' ')
          .strip
    end

    def model_path(name = model)
      return name if name.end_with?('.bin')

      File.join(MODELS_DIR, "ggml-#{name}.bin")
    end

    private

    def run_whisper(wav_path)
      cmd = [whisper_path, '-m', model_path, '-l', language, '-nt', '-np', '-f', wav_path]
      logger.debug "Whisper: #{cmd.join(' ')}"

      stdout, stderr, status = Open3.capture3(*cmd)
      raise ToolError, "Whisper transcription failed: #{stderr.lines.last(3).join.strip}" unless status.success?

      self.class.clean(stdout)
    end

    def with_wav(audio_path)
      return yield(audio_path) unless executable?(ffmpeg_path)

      Tempfile.create(['captcha_audio', '.wav']) do |wav|
        cmd = [ffmpeg_path, '-y', '-loglevel', 'error', '-i', audio_path, '-ar', '16000', '-ac', '1', wav.path]
        _, stderr, status = Open3.capture3(*cmd)
        raise ToolError, "ffmpeg could not decode the audio: #{stderr.strip}" unless status.success?

        yield wav.path
      end
    end

    def executable?(command)
      return File.executable?(command) if command.include?(File::SEPARATOR)

      ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, command)) }
    end

    def verify_whisper_available!
      return if available?

      raise ToolError,
            "whisper-cli not found (WHISPER_PATH=#{whisper_path}). Install whisper.cpp " \
            '(macOS: brew install whisper-cpp) or set WHISPER_PATH.'
    end

    def ensure_model_available!(name)
      return if File.exist?(model_path(name))
      raise ToolError, "Whisper model not found: #{model_path(name)}" if name.end_with?('.bin')
      raise ToolError, "Unknown Whisper model '#{name}'. Available: #{MODELS.join(', ')}" unless MODELS.include?(name)

      download_model(name)
    end

    def download_model(name)
      FileUtils.mkdir_p(MODELS_DIR)
      url = "#{MODEL_BASE_URL}/ggml-#{name}.bin"
      logger.info "Downloading Whisper model '#{name}' from #{url}"
      partial = "#{model_path(name)}.part"

      fetch(URI(url), partial)
      File.rename(partial, model_path(name))
      logger.info "Whisper model ready: #{model_path(name)}"
    rescue StandardError => e
      FileUtils.rm_f(partial) if partial
      raise ToolError, "Failed to download Whisper model '#{name}': #{e.message}"
    end

    def fetch(uri, destination, redirects: 5)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(Net::HTTP::Get.new(uri)) do |response|
          case response
          when Net::HTTPRedirection
            raise ToolError, 'Too many redirects' if redirects.zero?

            return fetch(URI.join(uri, response['location']), destination, redirects: redirects - 1)
          when Net::HTTPSuccess
            File.open(destination, 'wb') { |file| response.read_body { |chunk| file.write(chunk) } }
          else
            raise ToolError, "HTTP #{response.code}"
          end
        end
      end
    end
  end
end
