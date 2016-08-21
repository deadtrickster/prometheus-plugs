defmodule Plug.PrometheusExporter do
  @moduledoc """
  Renamed to Prometheus.PlugsExporter
  """

  require Logger
  import Plug.Conn
  @behaviour Plug

  def setup(_opts \\ []) do
    Logger.warn("Plug.PrometheusExporter was renamed to Prometheus.PlugsExporter")
    Prometheus.PlugsExporter.setup([])
  end

  def init(opts) do
    Logger.warn("Plug.PrometheusExporter was renamed to Prometheus.PlugsExporter")
    Prometheus.PlugsExporter.init(opts)
  end

  def call(conn, metadata) do
    Prometheus.PlugsExporter.call(conn, metadata)
  end
end
