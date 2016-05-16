defmodule Plug.PrometheusCollector do
  @moduledoc """
  A plug for exporting runtime and request information to prometheus monitoring system

  To use it, just plug it into the desired module.

  plug Plug.Prometheus
  """

  alias Plug.Conn
  @behaviour Plug

  def init(opts) do
    :prometheus.start    
    request_duration_bounds = Keyword.get(opts, :request_duration_bounds, [10, 100, 1_000, 10_000, 100_000, 300_000, 500_000, 750_000, 1_000_000, 1_500_000, 2_000_000, 3_000_000])
    labels = Keyword.get(opts, :labels, [:code, :method])
    :prometheus_counter.new([name: :http_requests_total,
                             help: "Total number of HTTP requests made.",
                             labels: labels])
    :prometheus_histogram.new([name: :http_request_duration_microseconds,
                               help: "The HTTP request latencies in microseconds.",
                               labels: labels,
                               bounds: request_duration_bounds])
    {labels}
  end

  def call(conn, {labels}) do

    start = current_time()

    Conn.register_before_send(conn, fn conn ->
      labels = construct_labels(labels, conn)
      :prometheus_counter.inc(:http_requests_total, labels)

      stop = current_time()
      diff = time_diff(start, stop)

      :prometheus_histogram.observe(:http_request_duration_microseconds, labels, diff)
      conn
    end)
  end

  # TODO: remove this once Plug supports only Elixir 1.2.
  if function_exported?(:erlang, :monotonic_time, 0) do
    defp current_time, do: :erlang.monotonic_time
    defp time_diff(start, stop), do: (stop - start) |> :erlang.convert_time_unit(:native, :micro_seconds)
  else
    defp current_time, do: :os.timestamp()
    defp time_diff(start, stop), do: :timer.now_diff(stop, start)
  end

  defp construct_labels(labels, conn) do
    for label <- labels, do: label_value(label, conn)
  end

  defp label_value(:code, conn), do: conn.status
  defp label_value(:method, conn), do: conn.method
  defp label_value(:host, conn), do: conn.host
  defp label_value(:scheme, conn), do: conn.scheme
  defp label_value(:port, conn), do: conn.port
end
