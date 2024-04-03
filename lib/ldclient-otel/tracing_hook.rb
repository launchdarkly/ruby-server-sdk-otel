require 'ldclient-rb'
require 'opentelemetry/sdk'

module LaunchDarkly
  module Otel
    class TracingHookOptions
      #
      # If set to true, then the tracing hook will add spans for each variation method call. Span events are always
      # added and are unaffected by this setting.
      #
      # The default value is false.
      #
      # @return [Boolean, nil]
      #
      attr_reader :add_spans

      #
      # If set to true, then the tracing hook will add the evaluated flag value to span events.
      #
      # The default is false.
      #
      # @return [Boolean]
      #
      attr_reader :include_variant

      #
      # The logger used for hook execution. Provide a custom logger or use the default which logs to the console.
      #
      # @return [Logger]
      #
      attr_reader :logger

      #
      # Configuration options to control the effect of the TracingHook.
      #
      # @param opts [Hash] the configuration options
      # @option opts [Boolean, nil] :add_spans See {#add_spans}.
      # @option opts [Boolean] :include_variant See {#include_variant}.
      # @option opts [Logger] :logger See {#logger}.
      #
      def initialize(opts = {})
        @add_spans = opts.fetch(:add_spans, nil)
        @include_variant = opts.fetch(:include_variant, false)
        @logger = opts[:logger] || LaunchDarkly::Otel.default_logger
      end
    end

    class TracingHook
      include LaunchDarkly::Interfaces::Hooks::Hook

      #
      # @param config [TracingHookOptions]
      #
      def initialize(config = TracingHookOptions.new())
        @config = config
        @tracer = OpenTelemetry.tracer_provider.tracer('launchdarkly')
      end

      #
      # Get metadata about the hook implementation.
      #
      # @return [Metadata]
      #
      def metadata
        LaunchDarkly::Interfaces::Hooks::Metadata.new('LaunchDarkly Tracing Hook')
      end

      #
      # The before method is called during the execution of a variation method before the flag value has been
      # determined. The method is executed synchronously.
      #
      # @param evaluation_series_context [EvaluationSeriesContext] Contains information about the evaluation being
      # performed. This is not mutable.
      # @param data [Hash] A record associated with each stage of hook invocations. Each stage is called with the data
      # of the previous stage for a series. The input record should not be modified.
      # @return [Hash] Data to use when executing the next state of the hook in the evaluation series.
      #
      def before_evaluation(evaluation_series_context, data)
        return data unless @config.add_spans

        attributes = {
          'feature_flag.context.key' => evaluation_series_context.context.fully_qualified_key,
          'feature_flag.key' => evaluation_series_context.key,
        }
        span = @tracer.start_span(evaluation_series_context.method, attributes: attributes)
        ctx = OpenTelemetry::Trace.context_with_span(span)
        token = OpenTelemetry::Context.attach(ctx)

        data.merge({span: span, token: token})
      end

      #
      # The after method is called during the execution of the variation method after the flag value has been
      # determined. The method is executed synchronously.
      #
      # @param evaluation_series_context [EvaluationSeriesContext] Contains read-only information about the evaluation
      # being performed.
      # @param data [Hash] A record associated with each stage of hook invocations. Each stage is called with the data
      # of the previous stage for a series.
      # @param detail [LaunchDarkly::EvaluationDetail] The result of the evaluation. This value should not be
      # modified.
      # @return [Hash] Data to use when executing the next state of the hook in the evaluation series.
      #
      def after_evaluation(evaluation_series_context, data, detail)
        if data[:span].is_a?(OpenTelemetry::Trace::Span)
          OpenTelemetry::Context.detach(data[:token])
          data[:span].finish()
        end

        span = OpenTelemetry::Trace.current_span
        return data if span.nil?

        event = {
          'feature_flag.key' => evaluation_series_context.key,
          'feature_flag.provider_name' => 'LaunchDarkly',
          'feature_flag.context.key' => evaluation_series_context.context.fully_qualified_key,
        }
        event['feature_flag.variant'] = detail.value.to_s if @config.include_variant

        span.add_event('feature_flag', attributes: event)

        data
      end
    end
  end
end
