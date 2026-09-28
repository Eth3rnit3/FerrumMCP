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
    MODELS = %w[tiny tiny.en base base.en small small.en medium medium.en large-v3-turbo].freeze
    MODEL_BASE_URL = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main'
    MODELS_DIR = File.expand_path('~/.whisper.cpp/models')

    attr_reader :whisper_path, :ffmpeg_path, :model, :language, :logger

    def initialize(model: nil, language: nil, logger: nil)
      @whisper_path = ENV.fetch('WHISPER_PATH', 'whisper-cli')
      @ffmpeg_path = ENV.fetch('FFMPEG_PATH', 'ffmpeg')
      @model = model || ENV.fetch('WHISPER_MODEL', 'base.en')
      @language = language || ENV.fetch('WHISPER_LANGUAGE', 'en')
      @logger = logger || Logger.new(File::NULL)
    end

    # Raise a ToolError explaining what is missing. Downloads the model if needed.
    def ensure_ready!
      verify_whisper_available!
      ensure_model_available!
      self
    end

    def available?
      executable?(whisper_path)
    end

    # @param bytes [String] raw audio (mp3, wav, ogg...)
    # @return [String] cleaned transcription
    def transcribe_bytes(bytes, extension: '.mp3')
      Tempfile.create(['captcha_audio', extension], binmode: true) do |file|
        file.write(bytes)
        file.flush
        transcribe(file.path)
      end
    end

    # @param audio_path [String] path to an audio file
    # @return [String] cleaned transcription
    def transcribe(audio_path)
      with_wav(audio_path) do |wav_path|
        cmd = [whisper_path, '-m', model_path, '-l', language, '-nt', '-np', '-f', wav_path]
        logger.debug "Whisper: #{cmd.join(' ')}"

        stdout, stderr, status = Open3.capture3(*cmd)
        raise ToolError, "Whisper transcription failed: #{stderr.lines.last(3).join.strip}" unless status.success?

        self.class.clean(stdout)
      end
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

    def model_path
      return model if model.end_with?('.bin')

      File.join(MODELS_DIR, "ggml-#{model}.bin")
    end

    private

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

    def ensure_model_available!
      return if File.exist?(model_path)
      raise ToolError, "Whisper model not found: #{model_path}" if model.end_with?('.bin')
      raise ToolError, "Unknown Whisper model '#{model}'. Available: #{MODELS.join(', ')}" unless MODELS.include?(model)

      download_model
    end

    def download_model
      FileUtils.mkdir_p(MODELS_DIR)
      url = "#{MODEL_BASE_URL}/ggml-#{model}.bin"
      logger.info "Downloading Whisper model '#{model}' from #{url}"
      partial = "#{model_path}.part"

      fetch(URI(url), partial)
      File.rename(partial, model_path)
      logger.info "Whisper model ready: #{model_path}"
    rescue StandardError => e
      FileUtils.rm_f(partial) if partial
      raise ToolError, "Failed to download Whisper model '#{model}': #{e.message}"
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
