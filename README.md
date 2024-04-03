LaunchDarkly Server-side OTEL library for Ruby
==============================================

[![Gem Version](https://badge.fury.io/rb/launchdarkly-server-sdk-otel.svg)](http://badge.fury.io/rb/launchdarkly-server-sdk-otel)

[![Quality Control](https://github.com/launchdarkly/ruby-server-sdk-otel/actions/workflows/ci.yml/badge.svg)](https://github.com/launchdarkly/ruby-server-sdk-otel/actions/workflows/ci.yml)
[![RubyDoc](https://img.shields.io/static/v1?label=docs+-+all+versions&message=reference&color=00add8)](https://www.rubydoc.info/gems/launchdarkly-server-sdk-otel)
[![GitHub Pages](https://img.shields.io/static/v1?label=docs+-+latest&message=reference&color=00add8)](https://launchdarkly.github.io/ruby-server-sdk-otel)

LaunchDarkly overview
-------------------------
[LaunchDarkly](https://www.launchdarkly.com) is a feature management platform that serves trillions of feature flags daily to help teams build better software, faster. [Get started](https://docs.launchdarkly.com/home/getting-started) using LaunchDarkly today!

[![Twitter Follow](https://img.shields.io/twitter/follow/launchdarkly.svg?style=social&label=Follow&maxAge=2592000)](https://twitter.com/intent/follow?screen_name=launchdarkly)

Supported Ruby versions
-----------------------

This version of the library has a minimum Ruby version of 3.0.0, or 9.4.0 for JRuby.

Getting started
-----------

Install the gem and add to the application's Gemfile by executing:

    $ bundle add launchdarkly-server-sdk-otel

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install launchdarkly-server-sdk-otel

The provided `TracingHook` can be setup as shown below:

```ruby
require 'ldclient-rb'
require 'ldclient-otel'
require 'opentelemetry/sdk'

config = LaunchDarkly::Config.new({logger: logger, hooks: [LaunchDarkly::Otel::TracingHook.new]})
client = LaunchDarkly::LDClient.new(sdk_key, config)

tracer = OpenTelemetry.tracer_provider.tracer('my_app_or_library', '0.1.0')
tracer.in_span('top-level span') do |span|
  _ = client.variation(feature_flag_key, context, false)
end
```

Learn more
-----------

Read our [documentation](http://docs.launchdarkly.com) for in-depth instructions on configuring and using LaunchDarkly. You can also head straight to the [reference guide for the ruby SDK](http://docs.launchdarkly.com/docs/ruby-sdk-reference).

Generated API documentation for all versions of the library is on [RubyDoc.info](https://www.rubydoc.info/gems/launchdarkly-server-sdk-otel). The API documentation for the latest version is also on [GitHub Pages](https://launchdarkly.github.io/ruby-server-sdk-otel).

Contributing
------------

We encourage pull requests and other contributions from the community. Check out our [contributing guidelines](CONTRIBUTING.md) for instructions on how to contribute to this library.

Verifying library build provenance with the SLSA framework
------------

LaunchDarkly uses the [SLSA framework](https://slsa.dev/spec/v1.0/about) (Supply-chain Levels for Software Artifacts) to help developers make their supply chain more secure by ensuring the authenticity and build integrity of our published library packages. To learn more, see the [provenance guide](PROVENANCE.md).

About LaunchDarkly
-----------

* LaunchDarkly is a continuous delivery platform that provides feature flags as a service and allows developers to iterate quickly and safely. We allow you to easily flag your features and manage them from the LaunchDarkly dashboard.  With LaunchDarkly, you can:
    * Roll out a new feature to a subset of your users (like a group of users who opt-in to a beta tester group), gathering feedback and bug reports from real-world use cases.
    * Gradually roll out a feature to an increasing percentage of users, and track the effect that the feature has on key metrics (for instance, how likely is a user to complete a purchase if they have feature A versus feature B?).
    * Turn off a feature that you realize is causing performance problems in production, without needing to re-deploy, or even restart the application with a changed configuration file.
    * Grant access to certain features based on user attributes, like payment plan (eg: users on the ‘gold’ plan get access to more features than users in the ‘silver’ plan). Disable parts of your application to facilitate maintenance, without taking everything offline.
* LaunchDarkly provides feature flag SDKs for a wide variety of languages and technologies. Read [our documentation](https://docs.launchdarkly.com/sdk) for a complete list.
* Explore LaunchDarkly
    * [launchdarkly.com](https://www.launchdarkly.com/ "LaunchDarkly Main Website") for more information
    * [docs.launchdarkly.com](https://docs.launchdarkly.com/  "LaunchDarkly Documentation") for our documentation and SDK reference guides
    * [apidocs.launchdarkly.com](https://apidocs.launchdarkly.com/  "LaunchDarkly API Documentation") for our API documentation
    * [blog.launchdarkly.com](https://blog.launchdarkly.com/  "LaunchDarkly Blog Documentation") for the latest product updates
