# frozen_string_literal: true

require 'opentelemetry/sdk'
require 'ldclient-rb'
require 'ldclient-otel/tracing_hook'

RSpec.describe LaunchDarkly::Otel do
  let(:td) { LaunchDarkly::Integrations::TestData.data_source() }
  let(:exporter) { OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new }
  let(:tracer) { OpenTelemetry.tracer_provider.tracer('rspec', '0.1.0') }

  before do
    OpenTelemetry::SDK.configure do |c|
      c.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter))
    end
  end

  context 'with default options' do
    let(:hook) { LaunchDarkly::Otel::TracingHook.new }
    let(:config) { LaunchDarkly::Config.new({data_source: td, hooks: [hook]}) }
    let(:client) { LaunchDarkly::LDClient.new('key', config) }

    it 'records nothing if not within a span' do
      result = client.variation('boolean', {key: 'org-key', kind: 'org'}, true)

      spans = exporter.finished_spans
      expect(spans.count).to eq 0
    end

    it 'records basic span event' do
      tracer.in_span('toplevel') do |span|
        result = client.variation('boolean', {key: 'org-key', kind: 'org'}, true)
      end

      spans = exporter.finished_spans

      expect(spans.count).to eq 1
      expect(spans[0].events.count).to eq 1

      event = spans[0].events[0]
      expect(event.name).to eq 'feature_flag'
      expect(event.attributes['feature_flag.key']).to eq 'boolean'
      expect(event.attributes['feature_flag.provider.name']).to eq 'LaunchDarkly'
      expect(event.attributes['feature_flag.context.id']).to eq 'org:org-key'
      expect(event.attributes['feature_flag.result.value']).to be_nil
    end
  end

  context 'with include_value' do
    let(:options) { LaunchDarkly::Otel::TracingHookOptions.new({include_value: true}) }
    let(:hook) { LaunchDarkly::Otel::TracingHook.new(options) }
    let(:config) { LaunchDarkly::Config.new({data_source: td, hooks: [hook]}) }
    let(:client) { LaunchDarkly::LDClient.new('key', config) }

    it 'is set in event' do
      flag = LaunchDarkly::Integrations::TestData::FlagBuilder.new('boolean').boolean_flag
      td.update(flag)

      tracer.in_span('toplevel') do |span|
        result = client.variation('boolean', {key: 'org-key', kind: 'org'}, false)
      end

      spans = exporter.finished_spans
      event = spans[0].events[0]
      expect(event.name).to eq 'feature_flag'
      expect(event.attributes['feature_flag.key']).to eq 'boolean'
      expect(event.attributes['feature_flag.provider.name']).to eq 'LaunchDarkly'
      expect(event.attributes['feature_flag.context.id']).to eq 'org:org-key'
      expect(event.attributes['feature_flag.result.value']).to eq 'true'
    end
  end

  context 'with include_variant (deprecated)' do
    let(:options) { LaunchDarkly::Otel::TracingHookOptions.new({include_variant: true}) }
    let(:hook) { LaunchDarkly::Otel::TracingHook.new(options) }
    let(:config) { LaunchDarkly::Config.new({data_source: td, hooks: [hook]}) }
    let(:client) { LaunchDarkly::LDClient.new('key', config) }

    it 'still works for backward compatibility' do
      flag = LaunchDarkly::Integrations::TestData::FlagBuilder.new('boolean').boolean_flag
      td.update(flag)

      tracer.in_span('toplevel') do |span|
        result = client.variation('boolean', {key: 'org-key', kind: 'org'}, false)
      end

      spans = exporter.finished_spans
      event = spans[0].events[0]
      expect(event.attributes['feature_flag.result.value']).to eq 'true'
    end
  end

  context 'with add_spans' do
    let(:options) { LaunchDarkly::Otel::TracingHookOptions.new({add_spans: true}) }
    let(:hook) { LaunchDarkly::Otel::TracingHook.new(options) }
    let(:config) { LaunchDarkly::Config.new({data_source: td, hooks: [hook]}) }
    let(:client) { LaunchDarkly::LDClient.new('key', config) }

    it 'creates a span if one is not active' do
      result = client.variation('boolean', {key: 'org-key', kind: 'org'}, false)

      spans = exporter.finished_spans
      expect(spans.count).to eq 1

      expect(spans[0].attributes['feature_flag.context.id']).to eq 'org:org-key'
      expect(spans[0].attributes['feature_flag.key']).to eq 'boolean'
      expect(spans[0].events).to be_nil
    end

    it 'events are set on top level span' do
      flag = LaunchDarkly::Integrations::TestData::FlagBuilder.new('boolean').boolean_flag
      td.update(flag)

      tracer.in_span('toplevel') do |span|
        result = client.variation('boolean', {key: 'org-key', kind: 'org'}, false)
      end

      spans = exporter.finished_spans
      expect(spans.count).to eq 2

      ld_span = spans[0]
      toplevel = spans[1]

      expect(ld_span.attributes['feature_flag.context.id']).to eq 'org:org-key'
      expect(ld_span.attributes['feature_flag.key']).to eq 'boolean'

      event = toplevel.events[0]
      expect(event.name).to eq 'feature_flag'
      expect(event.attributes['feature_flag.key']).to eq 'boolean'
      expect(event.attributes['feature_flag.provider.name']).to eq 'LaunchDarkly'
      expect(event.attributes['feature_flag.context.id']).to eq 'org:org-key'
      expect(event.attributes['feature_flag.result.value']).to be_nil
    end

    it 'hook makes its span active' do
      client.add_hook(LaunchDarkly::Otel::TracingHook.new(options))

      flag = LaunchDarkly::Integrations::TestData::FlagBuilder.new('boolean').boolean_flag
      td.update(flag)

      tracer.in_span('toplevel') do |span|
        result = client.variation('boolean', {key: 'org-key', kind: 'org'}, false)
      end

      spans = exporter.finished_spans
      expect(spans.count).to eq 3

      inner = spans[0]
      middle = spans[1]
      top = spans[2]

      expect(inner.attributes['feature_flag.context.id']).to eq 'org:org-key'
      expect(inner.attributes['feature_flag.key']).to eq 'boolean'
      expect(inner.events).to be_nil

      expect(middle.attributes['feature_flag.context.id']).to eq 'org:org-key'
      expect(middle.attributes['feature_flag.key']).to eq 'boolean'
      expect(middle.events[0].name).to eq 'feature_flag'
      expect(middle.events[0].attributes['feature_flag.key']).to eq 'boolean'
      expect(middle.events[0].attributes['feature_flag.provider.name']).to eq 'LaunchDarkly'
      expect(middle.events[0].attributes['feature_flag.context.id']).to eq 'org:org-key'
      expect(middle.events[0].attributes['feature_flag.result.value']).to be_nil

      expect(top.events[0].name).to eq 'feature_flag'
      expect(top.events[0].attributes['feature_flag.key']).to eq 'boolean'
      expect(top.events[0].attributes['feature_flag.provider.name']).to eq 'LaunchDarkly'
      expect(top.events[0].attributes['feature_flag.context.id']).to eq 'org:org-key'
      expect(top.events[0].attributes['feature_flag.result.value']).to be_nil
    end

  context 'with environment_id' do
    let(:options) { LaunchDarkly::Otel::TracingHookOptions.new({environment_id: 'test-env-123'}) }
    let(:hook) { LaunchDarkly::Otel::TracingHook.new(options) }
    let(:config) { LaunchDarkly::Config.new({data_source: td, hooks: [hook]}) }
    let(:client) { LaunchDarkly::LDClient.new('key', config) }

    it 'includes environment_id in event' do
      tracer.in_span('toplevel') do |span|
        result = client.variation('boolean', {key: 'org-key', kind: 'org'}, true)
      end

      spans = exporter.finished_spans
      event = spans[0].events[0]
      expect(event.attributes['feature_flag.set.id']).to eq 'test-env-123'
    end

    it 'does not include environment_id when invalid' do
      invalid_options = LaunchDarkly::Otel::TracingHookOptions.new({environment_id: ''})
      invalid_hook = LaunchDarkly::Otel::TracingHook.new(invalid_options)
      invalid_config = LaunchDarkly::Config.new({data_source: td, hooks: [invalid_hook]})
      invalid_client = LaunchDarkly::LDClient.new('key', invalid_config)

      tracer.in_span('toplevel') do |span|
        result = invalid_client.variation('boolean', {key: 'org-key', kind: 'org'}, true)
      end

      spans = exporter.finished_spans
      event = spans[0].events[0]
      expect(event.attributes['feature_flag.set.id']).to be_nil
    end
  end

  context 'with inExperiment and variationIndex' do
    let(:hook) { LaunchDarkly::Otel::TracingHook.new }
    let(:config) { LaunchDarkly::Config.new({data_source: td, hooks: [hook]}) }
    let(:client) { LaunchDarkly::LDClient.new('key', config) }

    it 'includes inExperiment when evaluation is part of experiment' do
      flag = LaunchDarkly::Integrations::TestData::FlagBuilder.new('experiment-flag')
        .variations(false, true)
        .fallthrough_variation(1)
        .on(true)
      td.update(flag)

      tracer.in_span('toplevel') do |span|
        result = client.variation('experiment-flag', {key: 'user-key', kind: 'user'}, false)
      end

      spans = exporter.finished_spans
      event = spans[0].events[0]
      expect(event.attributes.key?('feature_flag.result.reason.inExperiment')).to be false
    end

    it 'includes variationIndex when available' do
      flag = LaunchDarkly::Integrations::TestData::FlagBuilder.new('indexed-flag')
        .variations('value-0', 'value-1', 'value-2')
        .fallthrough_variation(1)
        .on(true)
      td.update(flag)

      tracer.in_span('toplevel') do |span|
        result = client.variation('indexed-flag', {key: 'user-key', kind: 'user'}, 'default')
      end

      spans = exporter.finished_spans
      event = spans[0].events[0]
      expect(event.attributes['feature_flag.result.variationIndex']).to eq 1
    end
  end

  end
end
