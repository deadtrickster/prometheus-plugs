defmodule Plug.PrometheusCollector do
  @moduledoc """
  Plug for collecting http metrics.

  To use it, plug it into the desired module.
  You also want to call `setup/0,1` before using plug, for example on application start!

  plug Plug.PrometheusCollector

  Currently maintains two metrics.
   - `http_requests_total` - Total nubmer of HTTP requests made. This one is a counter.
   - `http_request_duration_microseconds` - The HTTP request latencies in microseconds. This one is a histogram.

  All metrics support configurable labels:
  ```elixir
  # on app startup (e.g. supervisor setup)
  Plug.PrometheusCollector.setup([:method, :host])
  
  # in your plugs pipeline
  plug Plug.PrometheusCollector, [:method, :host]

  ```
  Supported labels include:
   - status_code - http code
   - status_class - http code class, like "success", "redirect", "client-error", etc
   - method - http method
   - host - requested host
   - port - requested port
   - scheme - request scheme (like http or https)

  In fact almost any [Plug.Conn](https://hexdocs.pm/plug/Plug.Conn.html) field value can be used as metric label.
  In order to create a custom label simply provide a fun as either a key-value
  pair where the value is a fun which will be given the label and conn as
  parameters:
  ``` elixir
  defmodule CustomLabels do
    def connection_private_key(key, conn) do
      Map.get(conn.private, key, "unknown") |> to_string
    end

    def phoenix_controller_action(%Plug.Conn{private: private}) do
      case [private[:phoenix_controller], private[:phoenix_action]] do
        [nil, nil] -> "unknown"
        [controller, action] -> "\#{controller}/\#{action}"
      end
    end
  end

  # As a key/value for the Collector
  Plug.PrometheusCollector.setup(labels: [:method, :phoenix_controller]
  plug Plug.PrometheusCollector, [:code, phoenix_controller: &CustomLabels.connection_private_key/2]

  # As a simple fun
  Plug.PrometheusCollector.setup(labels: [:method, :phoenix_controller_action]
  plug Plug.PrometheusCollector, [:code, &CustomLabels.phoenix_controller_action/1]
  ```

  Additionaly `http_request_duration_microseconds` supports configurable bucket bounds:
  ```elixir
  Plug.PrometheusCollector.setup([labels: [:method, :host],
                                 request_duration_bounds: [10, 100, 1_000, 10_000, 100_000, 300_000, 500_000, 750_000, 1_000_000, 1_500_000, 2_000_000, 3_000_000]])

  plug Plug.PrometheusCollector, [:method, :host]
  ```

  Bear in mind that bounds are ***microseconds*** (1s is 1_000_000us)
  """

  alias Plug.Conn
  require Logger
  @behaviour Plug

  def setup(opts \\ []) do
    request_duration_bounds = Keyword.get(opts, :request_duration_bounds, [10, 100, 1_000, 10_000, 100_000, 300_000, 500_000, 750_000, 1_000_000, 1_500_000, 2_000_000, 3_000_000])
    labels = Keyword.fetch!(opts, :labels)
    :prometheus_counter.declare([name: :http_requests_total,
                                 help: "Total number of HTTP requests made.",
                                 labels: labels])
    :prometheus_histogram.declare([name: :http_request_duration_microseconds,
                                   help: "The HTTP request latencies in microseconds.",
                                   labels: labels,
                                   buckets: request_duration_bounds])
    maybe_register_process_collector()
  end

  def init(labels) do
    if Enum.member?(labels, :code) do
      Logger.warn("PrometheusCollector: `code` label is deprecated. Probably can be replaced with `status_class`. Or if you still need numbers use `status_code`.")
    end
    labels
  end

  def call(conn, labels) do
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

  if Code.ensure_loaded?(:prometheus_process_collector) do
    defp maybe_register_process_collector do
      :prometheus_process_collector.register()
    end
  else
    defp maybe_register_process_collector do
    end
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
  defp label_value(:status_code, conn), do: conn.status
  defp label_value(:status_class, conn), do: :prometheus_http.status_class(conn.status)
  defp label_value(:method, conn), do: conn.method
  defp label_value(:host, conn), do: conn.host
  defp label_value(:scheme, conn), do: conn.scheme
  defp label_value(:port, conn), do: conn.port
  defp label_value({label, fun}, conn) when is_function(fun, 2), do: fun.(label, conn)
  defp label_value(fun, conn) when is_function(fun, 1), do: fun.(conn)
end
