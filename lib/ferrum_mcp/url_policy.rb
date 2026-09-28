# frozen_string_literal: true

require 'ipaddr'
require 'uri'

module FerrumMCP
  # Optional navigation policy built from ALLOWED_HOSTS / BLOCKED_HOSTS.
  #
  # Each list is comma-separated. An entry is an exact host ("example.com"),
  # a wildcard suffix ("*.example.com", which also matches "example.com"), or a
  # CIDR range for IP literals ("10.0.0.0/8", "169.254.169.254/32").
  #
  # - When ALLOWED_HOSTS is set, only matching hosts may be visited.
  # - BLOCKED_HOSTS always wins over ALLOWED_HOSTS.
  # - Both empty (the default) means no restriction.
  #
  # This is a best-effort guard for exposed HTTP deployments; it checks the
  # URL as written and does not resolve DNS.
  class UrlPolicy
    class BlockedURLError < Error; end

    attr_reader :allowed, :blocked

    def self.from_env(env = ENV)
      new(allowed: parse_list(env['ALLOWED_HOSTS']), blocked: parse_list(env['BLOCKED_HOSTS']))
    end

    def self.parse_list(value)
      value.to_s.split(',').map(&:strip).reject(&:empty?)
    end

    def initialize(allowed: [], blocked: [])
      @allowed = allowed.map { |e| compile(e) }
      @blocked = blocked.map { |e| compile(e) }
    end

    def restricted?
      @allowed.any? || @blocked.any?
    end

    def allowed?(url)
      host = host_of(url)
      return false unless host
      return false if @blocked.any? { |m| m.call(host) }
      return true if @allowed.empty?

      @allowed.any? { |m| m.call(host) }
    end

    def check!(url)
      return if !restricted? || allowed?(url)

      raise BlockedURLError, "Navigation to #{host_of(url) || url} is not allowed by the server URL policy"
    end

    private

    def host_of(url)
      host = URI.parse(url.to_s).host
      return nil unless host

      host.downcase.delete_prefix('[').delete_suffix(']')
    rescue URI::InvalidURIError
      nil
    end

    def compile(entry)
      entry = entry.downcase
      if entry.include?('/')
        range = IPAddr.new(entry)
        ->(host) { ip?(host) && range.include?(IPAddr.new(host)) }
      elsif entry.start_with?('*.')
        suffix = entry.delete_prefix('*')
        bare = entry.delete_prefix('*.')
        ->(host) { host == bare || host.end_with?(suffix) }
      else
        ->(host) { host == entry }
      end
    end

    def ip?(host)
      IPAddr.new(host)
      true
    rescue IPAddr::InvalidAddressError
      false
    end
  end
end
