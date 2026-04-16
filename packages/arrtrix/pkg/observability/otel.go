package observability

import (
	"context"
	"errors"
	"fmt"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/rs/zerolog"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	otellog "go.opentelemetry.io/otel/log"
	logglobal "go.opentelemetry.io/otel/log/global"
	otelmetric "go.opentelemetry.io/otel/metric"
	sdklog "go.opentelemetry.io/otel/sdk/log"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/trace"
)

const (
	instrumentationScope = "sneeuwvlok/packages/arrtrix"
	logScope             = instrumentationScope + "/logs"
)

type Runtime struct {
	traceProvider *sdktrace.TracerProvider
	meterProvider *sdkmetric.MeterProvider
	logProvider   *sdklog.LoggerProvider
	logHook       zerolog.Hook
}

type exporterEndpoint struct {
	raw      string
	insecure bool
}

type instruments struct {
	webhookRequests    otelCounter
	webhookLatency     otelHistogram
	commandInvocations otelCounter
	inviteEvents       otelCounter
	startupDuration    otelHistogram
}

type otelCounter interface {
	Add(context.Context, int64, ...otelmetric.AddOption)
}

type otelHistogram interface {
	Record(context.Context, float64, ...otelmetric.RecordOption)
}

var (
	mu           sync.RWMutex
	current      instruments
	tracer       = otel.Tracer(instrumentationScope)
	currentReady bool
)

func Setup(ctx context.Context, cfg Config, version string) (*Runtime, error) {
	cfg.ApplyDefaults()
	if !cfg.Enabled() {
		resetInstruments()
		return &Runtime{}, nil
	}

	res, err := buildResource(cfg, version)
	if err != nil {
		return nil, err
	}
	endpoint, err := parseEndpoint(cfg.OTLPGRPCEndpoint)
	if err != nil {
		return nil, err
	}

	traceExporter, err := otlptracegrpc.New(ctx, traceOptions(endpoint)...)
	if err != nil {
		return nil, fmt.Errorf("create trace exporter: %w", err)
	}
	metricExporter, err := otlpmetricgrpc.New(ctx, metricOptions(endpoint)...)
	if err != nil {
		return nil, fmt.Errorf("create metric exporter: %w", err)
	}
	logExporter, err := otlploggrpc.New(ctx, logOptions(endpoint)...)
	if err != nil {
		return nil, fmt.Errorf("create log exporter: %w", err)
	}

	traceProvider := sdktrace.NewTracerProvider(
		sdktrace.WithResource(res),
		sdktrace.WithBatcher(traceExporter),
	)
	meterProvider := sdkmetric.NewMeterProvider(
		sdkmetric.WithResource(res),
		sdkmetric.WithReader(sdkmetric.NewPeriodicReader(metricExporter, sdkmetric.WithInterval(30*time.Second))),
	)
	logProvider := sdklog.NewLoggerProvider(
		sdklog.WithResource(res),
		sdklog.WithProcessor(sdklog.NewBatchProcessor(logExporter)),
	)

	otel.SetTracerProvider(traceProvider)
	otel.SetMeterProvider(meterProvider)
	logglobal.SetLoggerProvider(logProvider)

	if err = setInstruments(meterProvider); err != nil {
		_ = traceProvider.Shutdown(ctx)
		_ = meterProvider.Shutdown(ctx)
		_ = logProvider.Shutdown(ctx)
		return nil, err
	}

	tracer = otel.Tracer(instrumentationScope)
	return &Runtime{
		traceProvider: traceProvider,
		meterProvider: meterProvider,
		logProvider:   logProvider,
		logHook:       newLogHook(logglobal.Logger(logScope)),
	}, nil
}

func (r *Runtime) Enabled() bool {
	return r != nil && r.traceProvider != nil
}

func (r *Runtime) LoggerHook() zerolog.Hook {
	if r == nil {
		return nil
	}
	return r.logHook
}

func (r *Runtime) Shutdown(ctx context.Context) error {
	if r == nil || !r.Enabled() {
		resetInstruments()
		return nil
	}

	var errs []error
	if err := r.logProvider.Shutdown(ctx); err != nil {
		errs = append(errs, fmt.Errorf("shutdown log provider: %w", err))
	}
	if err := r.meterProvider.Shutdown(ctx); err != nil {
		errs = append(errs, fmt.Errorf("shutdown meter provider: %w", err))
	}
	if err := r.traceProvider.Shutdown(ctx); err != nil {
		errs = append(errs, fmt.Errorf("shutdown trace provider: %w", err))
	}
	resetInstruments()
	return errors.Join(errs...)
}

func StartSpan(ctx context.Context, name string, opts ...trace.SpanStartOption) (context.Context, trace.Span) {
	return tracer.Start(ctx, name, opts...)
}

func RecordWebhook(ctx context.Context, eventType, outcome string, statusCode int, duration time.Duration) {
	mu.RLock()
	inst := current
	ready := currentReady
	mu.RUnlock()
	if !ready {
		return
	}
	attrs := otelmetric.WithAttributes(
		attribute.String("event_type", eventType),
		attribute.String("outcome", outcome),
		attribute.Int("http.status_code", statusCode),
	)
	inst.webhookRequests.Add(ctx, 1, attrs)
	inst.webhookLatency.Record(ctx, duration.Seconds(), attrs)
}

func RecordCommand(ctx context.Context, name, outcome string) {
	mu.RLock()
	inst := current
	ready := currentReady
	mu.RUnlock()
	if !ready {
		return
	}
	inst.commandInvocations.Add(ctx, 1, otelmetric.WithAttributes(
		attribute.String("command", name),
		attribute.String("outcome", outcome),
	))
}

func RecordInvite(ctx context.Context, outcome string) {
	mu.RLock()
	inst := current
	ready := currentReady
	mu.RUnlock()
	if !ready {
		return
	}
	inst.inviteEvents.Add(ctx, 1, otelmetric.WithAttributes(attribute.String("outcome", outcome)))
}

func RecordStartupPhase(ctx context.Context, phase, outcome string, duration time.Duration) {
	mu.RLock()
	inst := current
	ready := currentReady
	mu.RUnlock()
	if !ready {
		return
	}
	inst.startupDuration.Record(ctx, duration.Seconds(), otelmetric.WithAttributes(
		attribute.String("phase", phase),
		attribute.String("outcome", outcome),
	))
}

func parseEndpoint(raw string) (exporterEndpoint, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return exporterEndpoint{}, errors.New("observability.otlp_grpc_endpoint must not be empty when observability is enabled")
	}
	if strings.Contains(raw, "://") {
		u, err := url.Parse(raw)
		if err != nil {
			return exporterEndpoint{}, fmt.Errorf("parse observability.otlp_grpc_endpoint: %w", err)
		}
		if u.Scheme == "" || u.Host == "" {
			return exporterEndpoint{}, fmt.Errorf("invalid observability.otlp_grpc_endpoint %q", raw)
		}
		return exporterEndpoint{raw: raw, insecure: u.Scheme == "http"}, nil
	}
	return exporterEndpoint{raw: "http://" + raw, insecure: true}, nil
}

func buildResource(cfg Config, version string) (*resource.Resource, error) {
	attrs := []attribute.KeyValue{
		attribute.String("service.name", cfg.ServiceName),
	}
	if version != "" {
		attrs = append(attrs, attribute.String("service.version", version))
	}
	for key, value := range cfg.ResourceAttributes {
		attrs = append(attrs, attribute.String(key, value))
	}
	return resource.Merge(resource.Default(), resource.NewWithAttributes("", attrs...))
}

func setInstruments(provider *sdkmetric.MeterProvider) error {
	meter := provider.Meter(instrumentationScope)

	webhookRequests, err := meter.Int64Counter(
		"arrtrix.webhook.requests",
		otelmetric.WithDescription("Number of Arr webhook requests handled by arrtrix."),
	)
	if err != nil {
		return fmt.Errorf("create webhook request counter: %w", err)
	}
	webhookLatency, err := meter.Float64Histogram(
		"arrtrix.webhook.duration.seconds",
		otelmetric.WithDescription("Duration of Arr webhook request handling."),
		otelmetric.WithUnit("s"),
	)
	if err != nil {
		return fmt.Errorf("create webhook duration histogram: %w", err)
	}
	commandInvocations, err := meter.Int64Counter(
		"arrtrix.matrix.commands",
		otelmetric.WithDescription("Number of Matrix management-room commands handled by arrtrix."),
	)
	if err != nil {
		return fmt.Errorf("create command counter: %w", err)
	}
	inviteEvents, err := meter.Int64Counter(
		"arrtrix.matrix.invites",
		otelmetric.WithDescription("Number of management-room invite flows observed by arrtrix."),
	)
	if err != nil {
		return fmt.Errorf("create invite counter: %w", err)
	}
	startupDuration, err := meter.Float64Histogram(
		"arrtrix.runtime.phase.duration.seconds",
		otelmetric.WithDescription("Duration of arrtrix runtime startup and shutdown phases."),
		otelmetric.WithUnit("s"),
	)
	if err != nil {
		return fmt.Errorf("create runtime duration histogram: %w", err)
	}

	mu.Lock()
	current = instruments{
		webhookRequests:    webhookRequests,
		webhookLatency:     webhookLatency,
		commandInvocations: commandInvocations,
		inviteEvents:       inviteEvents,
		startupDuration:    startupDuration,
	}
	currentReady = true
	mu.Unlock()
	return nil
}

func resetInstruments() {
	mu.Lock()
	current = instruments{}
	currentReady = false
	mu.Unlock()
}

func traceOptions(endpoint exporterEndpoint) []otlptracegrpc.Option {
	opts := []otlptracegrpc.Option{otlptracegrpc.WithEndpointURL(endpoint.raw)}
	if endpoint.insecure {
		opts = append(opts, otlptracegrpc.WithInsecure())
	}
	return opts
}

func metricOptions(endpoint exporterEndpoint) []otlpmetricgrpc.Option {
	opts := []otlpmetricgrpc.Option{otlpmetricgrpc.WithEndpointURL(endpoint.raw)}
	if endpoint.insecure {
		opts = append(opts, otlpmetricgrpc.WithInsecure())
	}
	return opts
}

func logOptions(endpoint exporterEndpoint) []otlploggrpc.Option {
	opts := []otlploggrpc.Option{otlploggrpc.WithEndpointURL(endpoint.raw)}
	if endpoint.insecure {
		opts = append(opts, otlploggrpc.WithInsecure())
	}
	return opts
}

type otelLogHook struct {
	logger otellog.Logger
}

func newLogHook(logger otellog.Logger) zerolog.Hook {
	return otelLogHook{logger: logger}
}

func (h otelLogHook) Run(e *zerolog.Event, level zerolog.Level, message string) {
	if h.logger == nil {
		return
	}
	ctx := e.GetCtx()
	if ctx == nil {
		ctx = context.Background()
	}

	severity := mapSeverity(level)
	if !h.logger.Enabled(ctx, otellog.EnabledParameters{Severity: severity}) {
		return
	}

	now := time.Now()
	record := otellog.Record{}
	record.SetTimestamp(now)
	record.SetObservedTimestamp(now)
	record.SetSeverity(severity)
	record.SetSeverityText(strings.ToUpper(level.String()))
	record.SetBody(otellog.StringValue(message))
	record.AddAttributes(otellog.String("log.scope", logScope))

	if spanCtx := trace.SpanContextFromContext(ctx); spanCtx.IsValid() {
		record.AddAttributes(
			otellog.String("trace_id", spanCtx.TraceID().String()),
			otellog.String("span_id", spanCtx.SpanID().String()),
		)
	}

	h.logger.Emit(ctx, record)
}

func mapSeverity(level zerolog.Level) otellog.Severity {
	switch level {
	case zerolog.TraceLevel:
		return otellog.SeverityTrace
	case zerolog.DebugLevel:
		return otellog.SeverityDebug
	case zerolog.InfoLevel:
		return otellog.SeverityInfo
	case zerolog.WarnLevel:
		return otellog.SeverityWarn
	case zerolog.ErrorLevel:
		return otellog.SeverityError
	case zerolog.FatalLevel:
		return otellog.SeverityFatal
	case zerolog.PanicLevel:
		return otellog.SeverityFatal4
	default:
		return otellog.SeverityUndefined
	}
}
