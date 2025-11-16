# frozen_string_literal: true

module FerrumMCP
  # Manages MCP resources for browser configurations, profiles, and capabilities
  class ResourceManager
    attr_reader :config, :logger

    def initialize(config)
      @config = config
      @logger = config.logger
    end

    # Get all available resources
    def resources
      @resources ||= build_resources
    end

    # Read a specific resource by URI
    def read_resource(uri)
      case uri
      when 'ferrum://browsers'
        read_browsers_resource
      when 'ferrum://user-profiles'
        read_user_profiles_resource
      when 'ferrum://bot-profiles'
        read_bot_profiles_resource
      when 'ferrum://capabilities'
        read_capabilities_resource
      when %r{^ferrum://browsers/(.+)$}
        read_browser_detail(::Regexp.last_match(1))
      when %r{^ferrum://user-profiles/(.+)$}
        read_user_profile_detail(::Regexp.last_match(1))
      when %r{^ferrum://bot-profiles/(.+)$}
        read_bot_profile_detail(::Regexp.last_match(1))
      else
        logger.error "Unknown resource URI: #{uri}"
        nil
      end
    end

    private

    def build_resources
      resources = []

      # Browsers list resource
      resources << MCP::Resource.new(
        uri: 'ferrum://browsers',
        name: 'available-browsers',
        description: 'List of all available browser configurations',
        mime_type: 'application/json'
      )

      # Individual browser resources
      config.browsers.each do |browser|
        resources << MCP::Resource.new(
          uri: "ferrum://browsers/#{browser.id}",
          name: "browser-#{browser.id}",
          description: "Configuration for #{browser.name}",
          mime_type: 'application/json'
        )
      end

      # User profiles list resource
      resources << MCP::Resource.new(
        uri: 'ferrum://user-profiles',
        name: 'user-profiles',
        description: 'List of all available Chrome user profiles',
        mime_type: 'application/json'
      )

      # Individual user profile resources
      config.user_profiles.each do |profile|
        resources << MCP::Resource.new(
          uri: "ferrum://user-profiles/#{profile.id}",
          name: "user-profile-#{profile.id}",
          description: "Details for user profile: #{profile.name}",
          mime_type: 'application/json'
        )
      end

      # Bot profiles list resource
      resources << MCP::Resource.new(
        uri: 'ferrum://bot-profiles',
        name: 'bot-profiles',
        description: 'List of all available BotBrowser profiles',
        mime_type: 'application/json'
      )

      # Individual bot profile resources
      config.bot_profiles.each do |profile|
        resources << MCP::Resource.new(
          uri: "ferrum://bot-profiles/#{profile.id}",
          name: "bot-profile-#{profile.id}",
          description: "Details for BotBrowser profile: #{profile.name}",
          mime_type: 'application/json'
        )
      end

      # Capabilities resource
      resources << MCP::Resource.new(
        uri: 'ferrum://capabilities',
        name: 'server-capabilities',
        description: 'Server capabilities and feature flags',
        mime_type: 'application/json'
      )

      resources
    end

    def read_browsers_resource
      {
        uri: 'ferrum://browsers',
        mimeType: 'application/json',
        text: JSON.pretty_generate({
                                     browsers: config.browsers.map(&:to_h),
                                     default: config.default_browser&.id,
                                     total: config.browsers.count
                                   })
      }
    end

    def read_browser_detail(browser_id)
      browser = config.find_browser(browser_id)
      return nil unless browser

      {
        uri: "ferrum://browsers/#{browser_id}",
        mimeType: 'application/json',
        text: JSON.pretty_generate(browser.to_h.merge(
                                     is_default: browser == config.default_browser,
                                     exists: browser.path.nil? || File.exist?(browser.path),
                                     usage: {
                                       session_param: 'browser_id',
                                       example: "create_session(browser_id: '#{browser.id}')"
                                     }
                                   ))
      }
    end

    def read_user_profiles_resource
      {
        uri: 'ferrum://user-profiles',
        mimeType: 'application/json',
        text: JSON.pretty_generate({
                                     profiles: config.user_profiles.map(&:to_h),
                                     total: config.user_profiles.count,
                                     note: 'User profiles are standard Chrome user data directories'
                                   })
      }
    end

    def read_user_profile_detail(profile_id)
      profile = config.find_user_profile(profile_id)
      return nil unless profile

      {
        uri: "ferrum://user-profiles/#{profile_id}",
        mimeType: 'application/json',
        text: JSON.pretty_generate(profile.to_h.merge(
                                     exists: File.directory?(profile.path),
                                     usage: {
                                       session_param: 'user_profile_id',
                                       example: "create_session(user_profile_id: '#{profile.id}')"
                                     }
                                   ))
      }
    end

    def read_bot_profiles_resource
      {
        uri: 'ferrum://bot-profiles',
        mimeType: 'application/json',
        text: JSON.pretty_generate({
                                     profiles: config.bot_profiles.map(&:to_h),
                                     total: config.bot_profiles.count,
                                     note: 'BotBrowser profiles contain anti-detection fingerprints',
                                     using_botbrowser: config.using_botbrowser?
                                   })
      }
    end

    def read_bot_profile_detail(profile_id)
      profile = config.find_bot_profile(profile_id)
      return nil unless profile

      {
        uri: "ferrum://bot-profiles/#{profile_id}",
        mimeType: 'application/json',
        text: JSON.pretty_generate(profile.to_h.merge(
                                     exists: File.exist?(profile.path),
                                     usage: {
                                       session_param: 'bot_profile_id',
                                       example: "create_session(bot_profile_id: '#{profile.id}')"
                                     },
                                     features: %w[
                                       canvas_fingerprinting
                                       webgl_protection
                                       audio_context_hardening
                                       webrtc_leak_prevention
                                     ]
                                   ))
      }
    end

    def read_capabilities_resource
      {
        uri: 'ferrum://capabilities',
        mimeType: 'application/json',
        text: JSON.pretty_generate({
                                     version: FerrumMCP::VERSION,
                                     features: {
                                       multi_browser: config.browsers.count > 1,
                                       user_profiles: config.user_profiles.any?,
                                       bot_profiles: config.bot_profiles.any?,
                                       botbrowser_integration: config.using_botbrowser?,
                                       session_management: true,
                                       screenshot: true,
                                       javascript_execution: true,
                                       cookie_management: true,
                                       form_interaction: true,
                                       captcha_solving: true
                                     },
                                     transport: config.transport,
                                     browsers_count: config.browsers.count,
                                     user_profiles_count: config.user_profiles.count,
                                     bot_profiles_count: config.bot_profiles.count
                                   })
      }
    end
  end
end
