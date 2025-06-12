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
      expect(event.attributes['feature_flag.provider_name']).to eq 'LaunchDarkly'
      expect(event.attributes['feature_flag.context.key']).to eq 'org:org-key'
      expect(event.attributes['feature_flag.variant']).to be_nil
    end
  end

  context 'with include_variant' do
    let(:options) { LaunchDarkly::Otel::TracingHookOptions.new({include_variant: true}) }
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
      expect(event.attributes['feature_flag.provider_name']).to eq 'LaunchDarkly'
      expect(event.attributes['feature_flag.context.key']).to eq 'org:org-key'
      expect(event.attributes['feature_flag.variant']).to eq 'true'
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

      expect(spans[0].attributes['feature_flag.context.key']).to eq 'org:org-key'
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

      expect(ld_span.attributes['feature_flag.context.key']).to eq 'org:org-key'
      expect(ld_span.attributes['feature_flag.key']).to eq 'boolean'

      event = toplevel.events[0]
      expect(event.name).to eq 'feature_flag'
      expect(event.attributes['feature_flag.key']).to eq 'boolean'
      expect(event.attributes['feature_flag.provider_name']).to eq 'LaunchDarkly'
      expect(event.attributes['feature_flag.context.key']).to eq 'org:org-key'
      expect(event.attributes['feature_flag.variant']).to be_nil
    end

    it 'hook makes its span active' do
      # By adding the same hook twice, we should get 3 spans.
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

      expect(inner.attributes['feature_flag.context.key']).to eq 'org:org-key'
      expect(inner.attributes['feature_flag.key']).to eq 'boolean'
      expect(inner.events).to be_nil

      expect(middle.attributes['feature_flag.context.key']).to eq 'org:org-key'
      expect(middle.attributes['feature_flag.key']).to eq 'boolean'
      expect(middle.events[0].name).to eq 'feature_flag'
      expect(middle.events[0].attributes['feature_flag.key']).to eq 'boolean'
      expect(middle.events[0].attributes['feature_flag.provider_name']).to eq 'LaunchDarkly'
      expect(middle.events[0].attributes['feature_flag.context.key']).to eq 'org:org-key'
      expect(middle.events[0].attributes['feature_flag.variant']).to be_nil

      expect(top.events[0].name).to eq 'feature_flag'
      expect(top.events[0].attributes['feature_flag.key']).to eq 'boolean'
      expect(top.events[0].attributes['feature_flag.provider_name']).to eq 'LaunchDarkly'
      expect(top.events[0].attributes['feature_flag.context.key']).to eq 'org:org-key'
      expect(top.events[0].attributes['feature_flag.variant']).to be_nil
    end
  end
end
