# frozen_string_literal: true

require 'tempfile'
require 'open3'
require 'fileutils'
require 'net/http'
require 'uri'
require 'shellwords'

module FerrumMCP
  # Service to handle Whisper speech recognition for CAPTCHA solving
  # Uses whisper-cli (whisper.cpp) for fast, efficient transcription
  class WhisperService
    attr_reader :whisper_path, :model, :language, :logger

    # Model URLs for whisper.cpp
    MODEL_URLS = {
      'tiny' => 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin',
      'base' => 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin',
      'small' => 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin',
      'medium' => 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin'
    }.freeze

    def initialize(model: nil, language: nil, logger: nil)
      @whisper_path = ENV.fetch('WHISPER_PATH', 'whisper-cli')
      @model = model || ENV.fetch('WHISPER_MODEL', 'base')
      @language = language || ENV.fetch('WHISPER_LANGUAGE', 'en')
      @logger = logger || Logger.new($stdout)

      verify_whisper_available!
      ensure_model_available!
    end

    # Transcribe audio file to text
    # @param audio_path [String] Path to audio file
    # @return [String] Transcribed and cleaned text
    def transcribe(audio_path)
      logger.debug "Transcribing audio: #{audio_path}"

      cmd = build_whisper_command(audio_path)
      logger.debug "Command: #{cmd.join(' ')}"

      stdout, stderr, status = Open3.capture3(*cmd)

      unless status.success?
        logger.error "Whisper failed: #{stderr}"
        raise ToolError, "Whisper transcription failed: #{stderr}"
      end

      logger.debug "Whisper stdout: #{stdout}"

      # Extract transcription from output or file
      transcription = extract_transcription_from_output(stdout) || read_transcription_file(audio_path)
      clean_transcription(transcription)
    ensure
      # Cleanup .txt file created by whisper-cli
      txt_file = "#{audio_path}.txt"
      FileUtils.rm_f(txt_file)
    end

    # Download audio from URL using browser context
    # @param browser [Ferrum::Browser] Browser instance
    # @param url [String] Audio URL
    # @return [Tempfile] Temporary audio file
    def download_audio(_browser, url)
      temp_file = Tempfile.new(['captcha_audio', '.mp3'])
      temp_file.binmode

      logger.info "Downloading audio from: #{url[0..80]}..."

      # Use curl to download (simpler and more reliable)
      _, stderr, status = Open3.capture3("curl -s -L -o #{temp_file.path} #{url.shellescape}")

      unless status.success?
        logger.error "curl failed: #{stderr}"
        raise ToolError, "Failed to download audio with curl: #{stderr}"
      end

      # Verify file was downloaded
      unless File.exist?(temp_file.path) && File.size(temp_file.path).positive?
        raise ToolError, 'Audio file is empty or not downloaded'
      end

      logger.info "Downloaded: #{File.size(temp_file.path)} bytes"
      temp_file
    rescue StandardError => e
      temp_file&.close
      temp_file&.unlink
      raise ToolError, "Failed to download audio: #{e.message}"
    end

    # Check if Whisper is available
    # @return [Boolean]
    def available?
      verify_whisper_available!
      true
    rescue StandardError
      false
    end

    private

    def verify_whisper_available!
      _, stderr, status = Open3.capture3("#{whisper_path} --help 2>&1")

      unless status.success?
        raise ToolError,
              "Whisper not found at '#{whisper_path}'. " \
              "Install with: brew install whisper-cpp\n" \
              "Or on Linux: follow instructions at https://github.com/ggerganov/whisper.cpp\n" \
              "Or set WHISPER_PATH environment variable.\n" \
              "Error: #{stderr}"
      end

      logger.info "Whisper CLI available at: #{whisper_path}"
    end

    def ensure_model_available!
      model_path = get_model_path

      # Check if model already exists
      if File.exist?(model_path)
        logger.debug "Model already available: #{model_path}"
        return
      end

      # Download model
      logger.info "Model '#{model}' not found, downloading..."
      download_model(model_path)
    end

    def get_model_path # rubocop:disable Naming/AccessorMethodName
      models_dir = File.expand_path('~/.whisper.cpp/models')
      FileUtils.mkdir_p(models_dir)
      File.join(models_dir, "ggml-#{model}.bin")
    end

    def download_model(model_path) # rubocop:disable Metrics/AbcSize
      url = MODEL_URLS[model]

      raise ToolError, "Unknown model: #{model}. Available: #{MODEL_URLS.keys.join(', ')}" unless url

      logger.info "Downloading model from: #{url}"
      logger.info 'This may take a few minutes...'

      # Download with progress
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new(uri)

        http.request(request) do |response|
          raise ToolError, "Failed to download model: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

          total_size = response['content-length'].to_i
          downloaded = 0

          File.open(model_path, 'wb') do |file|
            response.read_body do |chunk|
              file.write(chunk)
              downloaded += chunk.size

              # Log progress every 10MB
              if (downloaded % (10 * 1024 * 1024)).zero? || downloaded == total_size
                progress = (downloaded * 100.0 / total_size).round(1)
                mb_downloaded = downloaded / 1024 / 1024
                mb_total = total_size / 1024 / 1024
                logger.info "Download progress: #{progress}% (#{mb_downloaded}MB / #{mb_total}MB)"
              end
            end
          end
        end
      end

      logger.info "Model downloaded successfully: #{model_path}"
    rescue StandardError => e
      FileUtils.rm_f(model_path)
      raise ToolError, "Failed to download model: #{e.message}"
    end

    def build_whisper_command(audio_path)
      model_path = get_model_path

      [
        whisper_path,
        '--model', model_path,
        '--language', language,
        '--output-txt',
        '--file', audio_path
      ]
    end

    def extract_transcription_from_output(output)
      # whisper-cli outputs the transcription in the stdout
      # Format: [00:00:00.000 --> 00:00:05.000]  transcription text here
      lines = output.lines.grep(/\]\s+\w/)
      return nil if lines.empty?

      # Extract text after the timestamp
      transcription = lines.map do |line|
        line.sub(/\[.*?\]\s*/, '').strip
      end.join(' ')

      transcription.empty? ? nil : transcription
    end

    def read_transcription_file(audio_path)
      # whisper-cli creates audio_path.txt in the same directory
      txt_file = "#{audio_path}.txt"

      raise ToolError, "Whisper output file not found: #{txt_file}" unless File.exist?(txt_file)

      File.read(txt_file).strip
    end

    def clean_transcription(text)
      text.strip
          .gsub(/\s+/, ' ')           # normalize whitespace
          .gsub(/[^\w\s]/, '')        # remove punctuation
          .downcase                   # lowercase for consistency
    end
  end
end
