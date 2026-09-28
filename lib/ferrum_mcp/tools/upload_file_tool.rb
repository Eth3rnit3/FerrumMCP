# frozen_string_literal: true

module FerrumMCP
  module Tools
    # Attach local files to an <input type="file">
    class UploadFileTool < BaseTool
      tool_name 'upload_file'
      description 'Attach one or more local files (from the server filesystem) to an <input type="file"> element. ' \
                  'Files must live under an allowed directory (UPLOAD_ALLOWED_DIRS).'

      param :selector, type: :string, required: true, description: 'Selector of the file input'
      param :paths, type: :array, required: true, description: 'Absolute paths of the files to attach',
                    schema: { items: { type: 'string' } }

      def perform(params)
        ensure_browser_active
        selector = params[:selector]
        paths = Array(params[:paths]).map { |p| authorized_path!(p.to_s) }
        raise ToolError, 'paths must not be empty' if paths.empty?

        logger.info "Uploading #{paths.length} file(s) to #{selector}"
        find_element(selector).select_file(paths)

        success_response(selector: selector, files: paths.map { |p| File.basename(p) }, count: paths.length)
      rescue StandardError => e
        logger.error "Upload failed: #{e.message}"
        error_response("Failed to upload file: #{e.message}")
      end

      private

      def authorized_path!(path)
        expanded = File.expand_path(path)
        raise ToolError, "File not found: #{path}" unless File.file?(expanded)

        real = File.realpath(expanded)
        allowed = @browser_manager.config.upload_allowed_dirs.filter_map { |dir| safe_realpath(dir) }
        return real if allowed.any? { |dir| real.start_with?("#{dir}/") }

        raise ToolError, "File #{path} is not allowed: uploads are restricted to #{allowed.join(', ')}"
      end

      def safe_realpath(dir)
        File.realpath(dir)
      rescue SystemCallError
        nil
      end
    end
  end
end
