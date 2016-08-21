defmodule Plug.PrometheusCollector do
  @moduledoc """
  Renamed to Prometheus.PlugsInstrumenter.
  """

  require Logger
  @behaviour Plug

  def setup(opts \\ []) do
    Logger.warn("Plug.PrometheusCollector was renamed to Prometheus.PlugsInstrumenter")
    Prometheus.PlugsInstrumenter.setup(opts)
  end

  def init(labels) do
    Logger.warn("Plug.PrometheusCollector was renamed to Prometheus.PlugsInstrumenter")
    Prometheus.PlugsInstrumenter.init(labels)
  end

  def call(conn, labels) do
    Prometheus.PlugsInstrumenter.call(conn, labels)
  end
end
