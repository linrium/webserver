# OpenTelemetry Debug Logging Guide

## Configuration Changes

I've enabled debug logging for OpenTelemetry in two files:

### [dev.exs](file:///Users/linh/Projects/webserver/config/dev.exs)
- Set logger level to `:debug`
- Added OpenTelemetry trace metadata to console output

### [opentelemetry.exs](file:///Users/linh/Projects/webserver/config/opentelemetry.exs)
- Added explicit processor configuration
- Enabled trace context propagators

## What to Look For

When you restart your application with `iex -S mix`, you should now see detailed logs including:

### 1. **Startup Logs**
```
[debug] Starting OpenTelemetry batch processor
[debug] OpenTelemetry exporter configured: http://localhost:4318
```

### 2. **Span Creation** (when you make HTTP requests)
```
[debug] Creating span: GET /
[debug] Span context: trace_id=..., span_id=...
```

### 3. **Span Export**
```
[debug] Exporting 1 span(s)
[debug] OTLP export successful
```

### 4. **Errors** (if any)
```
[error] OTLP export failed with error: ...
[warning] span exporter threw exception: ...
```

## Testing

1. **Restart your application**:
   ```bash
   # Stop current session (Ctrl+C twice if needed)
   iex -S mix
   ```

2. **Make a test request**:
   ```bash
   curl http://localhost:4000/
   ```

3. **Watch the console** for debug messages showing:
   - Span creation
   - Batch processing
   - Export to Tempo

## Expected Debug Output

You should see something like:
```
[info] Running Webserver.Router with Cowboy on http://localhost:4000
[debug] Starting batch span processor
[debug] Cowboy handler started
[debug] Creating span for request: GET /
[debug] Exporting spans to http://localhost:4318/v1/traces
[info] Sent 200 in 5ms
```

## Troubleshooting

If you see errors like:
- `connection refused` → Tempo is not running (`docker-compose up -d`)
- `timeout` → Check Tempo logs (`docker logs webserver-tempo-1`)
- `no spans exported` → No HTTP requests were made or Cowboy setup failed

## Additional Debug Options

If you need even more verbose logging, you can set environment variables:

```bash
OTEL_LOG_LEVEL=debug iex -S mix
```

Or add to your shell:
```bash
export OTEL_LOG_LEVEL=debug
export OTEL_TRACES_EXPORTER=otlp
```
