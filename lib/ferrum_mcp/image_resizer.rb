# frozen_string_literal: true

module FerrumMCP
  # Optional libvips-backed resizing. ruby-vips raises LoadError when the
  # native library is missing; screenshots are then returned at full size.
  module ImageResizer
    module_function

    def available?
      return @available unless @available.nil?

      @available = begin
        require 'vips'
        true
      rescue LoadError => e
        warn_once("libvips not available (#{e.message}); large screenshots will not be resized")
        false
      end
    end

    # Scale the image down so both sides fit within max_dimension
    def fit(image_data, max_dimension, format, logger: nil)
      image = Vips::Image.new_from_buffer(image_data, '')
      width = image.width
      height = image.height
      return image_data if width <= max_dimension && height <= max_dimension

      scale = [max_dimension.to_f / width, max_dimension.to_f / height].min
      new_width = (width * scale).to_i
      new_height = (height * scale).to_i
      logger&.info "Resizing screenshot from #{width}x#{height} to #{new_width}x#{new_height}"

      image.thumbnail_image(new_width, height: new_height, size: :force).write_to_buffer(".#{format}")
    end

    def warn_once(message)
      return if @warned

      @warned = true
      Kernel.warn "[ferrum-mcp] #{message}"
    end
  end
end
