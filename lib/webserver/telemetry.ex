defmodule Webserver.Telemetry do
  @moduledoc """
  OpenTelemetry instrumentation for the Webserver application.

  This module sets up telemetry handlers to create OpenTelemetry spans
  for various operations including HTTP requests, WebSocket connections,
  and distributed operations.
  """
  require OpenTelemetry.Tracer

  @doc """
  Attaches telemetry handlers for OpenTelemetry instrumentation.
  Should be called during application startup.
  """
  def setup do
    # Attach handlers for WebSocket events
    :telemetry.attach_many(
      "webserver-websocket-telemetry",
      [
        [:webserver, :websocket, :connect],
        [:webserver, :websocket, :disconnect],
        [:webserver, :websocket, :message]
      ],
      &handle_websocket_event/4,
      nil
    )

    # Attach handlers for distributed operations
    :telemetry.attach_many(
      "webserver-distributed-telemetry",
      [
        [:webserver, :kv, :put],
        [:webserver, :kv, :get],
        [:webserver, :chat, :broadcast]
      ],
      &handle_distributed_event/4,
      nil
    )

    :ok
  end

  # WebSocket event handlers
  defp handle_websocket_event(
         [:webserver, :websocket, :connect],
         _measurements,
         metadata,
         _config
       ) do
    OpenTelemetry.Tracer.with_span "websocket.connect" do
      OpenTelemetry.Tracer.set_attributes([
        {"websocket.peer", metadata[:peer] || "unknown"},
        {"websocket.connection_id", metadata[:connection_id] || "unknown"}
      ])
    end
  end

  defp handle_websocket_event(
         [:webserver, :websocket, :disconnect],
         measurements,
         metadata,
         _config
       ) do
    OpenTelemetry.Tracer.with_span "websocket.disconnect" do
      OpenTelemetry.Tracer.set_attributes([
        {"websocket.peer", metadata[:peer] || "unknown"},
        {"websocket.connection_id", metadata[:connection_id] || "unknown"},
        {"websocket.duration_ms", measurements[:duration] || 0}
      ])
    end
  end

  defp handle_websocket_event([:webserver, :websocket, :message], measurements, metadata, _config) do
    OpenTelemetry.Tracer.with_span "websocket.message" do
      OpenTelemetry.Tracer.set_attributes([
        {"websocket.message_type", metadata[:type] || "unknown"},
        {"websocket.message_size", measurements[:size] || 0}
      ])
    end
  end

  # Distributed operation event handlers
  defp handle_distributed_event([:webserver, :kv, :put], measurements, metadata, _config) do
    OpenTelemetry.Tracer.with_span "kv.put" do
      OpenTelemetry.Tracer.set_attributes([
        {"kv.key", metadata[:key] || "unknown"},
        {"kv.node", to_string(node())},
        {"kv.duration_us", measurements[:duration] || 0}
      ])
    end
  end

  defp handle_distributed_event([:webserver, :kv, :get], measurements, metadata, _config) do
    OpenTelemetry.Tracer.with_span "kv.get" do
      OpenTelemetry.Tracer.set_attributes([
        {"kv.key", metadata[:key] || "unknown"},
        {"kv.node", to_string(node())},
        {"kv.found", metadata[:found] || false},
        {"kv.duration_us", measurements[:duration] || 0}
      ])
    end
  end

  defp handle_distributed_event([:webserver, :chat, :broadcast], measurements, metadata, _config) do
    OpenTelemetry.Tracer.with_span "chat.broadcast" do
      OpenTelemetry.Tracer.set_attributes([
        {"chat.room", metadata[:room] || "default"},
        {"chat.sender", metadata[:sender] || "unknown"},
        {"chat.recipients", metadata[:recipient_count] || 0},
        {"chat.duration_us", measurements[:duration] || 0}
      ])
    end
  end
end
