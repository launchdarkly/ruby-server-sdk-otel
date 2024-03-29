# frozen_string_literal: true

require_relative 'ldclient-otel/tracing_hook'
require_relative 'ldclient-otel/version'
require 'logger'

module LaunchDarkly
  #
  # Namespace for the LaunchDarkly Otel SDK.
  #
  module Otel
    #
    # The default value for {#logger}.
    # @return [Logger] the Rails logger if in Rails, or a default Logger at WARN level otherwise
    #
    def self.default_logger
      if defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger
      else
        log = ::Logger.new($stdout)
        log.level = ::Logger::WARN
        log
      end
    end

  end
end
