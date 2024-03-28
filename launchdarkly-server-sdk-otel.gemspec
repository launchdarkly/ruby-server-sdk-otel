# frozen_string_literal: true

require_relative "lib/ldclient-otel/version"

Gem::Specification.new do |spec|
  spec.name = "launchdarkly-server-sdk-otel"
  spec.version = LaunchDarkly::Otel::VERSION
  spec.authors = ["LaunchDarkly"]
  spec.email = ["team@launchdarkly.com"]

  spec.summary = "LaunchDarkly SDK OTEL integration"
  spec.description = "LaunchDarkly SDK OTEL integration for the Ruby server side SDK"
  spec.homepage = "https://github.com/launchdarkly/ruby-server-sdk-otel"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/launchdarkly/ruby-server-sdk-otel"
  spec.metadata["changelog_uri"] = "https://github.com/launchdarkly/ruby-server-sdk-otel/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "launchdarkly-server-sdk", "~> 8.4"
  spec.add_runtime_dependency "opentelemetry-sdk", "~> 1.4.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
