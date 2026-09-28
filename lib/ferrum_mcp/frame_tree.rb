# frozen_string_literal: true

module FerrumMCP
  # Frame information read from CDP instead of Ferrum's Frame objects.
  #
  # Ferrum keeps frames left over from Chrome's New Tab page (the startup tab
  # BrowserManager drives) and they never get an execution context. Anything
  # evaluating in them, starting with Frame#url, waits for Ferrum's timeout.
  module FrameTree
    module_function

    # URL (fragment included) of every live frame, keyed by frame id
    # @return [Hash{String => String}]
    def urls(page)
      tree = page.command('Page.getFrameTree')['frameTree']
      flatten(tree).to_h { |frame| [frame['id'], "#{frame['url']}#{frame['urlFragment']}"] }
    rescue StandardError
      {}
    end

    def flatten(node)
      [node['frame']] + node['childFrames'].to_a.flat_map { |child| flatten(child) }
    end
  end
end
