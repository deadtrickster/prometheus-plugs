defmodule Prometheus.PlugsInstrumenter do
  @moduledoc """
  Plug for collecting http metrics.

  To use it, plug it into the desired module.
  You also want to call `setup/0` before using plug, for example on application start!

  plug Prometheus.PlugsInstrumenter

  Currently maintains two metrics.
   - `http_requests_total` - Total nubmer of HTTP requests made. This one is a counter.
   - `http_request_duration_microseconds` - The HTTP request latencies in microseconds. This one is a histogram.

  ```elixir
  # on app startup (e.g. supervisor setup)
  Prometheus.PlugsInstrumenter.setup()

  # in your plugs pipeline
  plug Prometheus.PlugsInstrumenter
  ```

  ### Configuration

  Plugs instrumenter can be configured via PlugsInstrumenter key of prometheus app env.

  All metrics support configurable labels:

  ```
   - status_code - http code
   - status_class - http code class, like "success", "redirect", "client-error", etc
   - method - http method
   - host - requested host
   - port - requested port
   - scheme - request scheme (like http or https)
  ```

  Default configuration:

  ```elixir
  config :prometheus, PlugsInstrumenter,
    labels: [:status_class, :method, :host, :scheme],
    duration_buckets:[10, 100, 1_000, 10_000, 100_000,
                      300_000, 500_000, 750_000, 1_000_000,
                      1_500_000, 2_000_000, 3_000_000],
    registry: :default
  ```

  In fact almost any [Plug.Conn](https://hexdocs.pm/plug/Plug.Conn.html) field value can be used as metric label.
  In order to create a custom label simply provide a fun as either a key-value
  pair where the value is a fun which will be given the label and conn as
  parameters:
  ``` elixir
  defmodule CustomLabels do
    def label_value(key, conn) do
      Map.get(conn.private, key, "unknown") |> to_string
    end

    def phoenix_controller_action(%Plug.Conn{private: private}) do
      case [private[:phoenix_controller], private[:phoenix_action]] do
        [nil, nil] -> "unknown"
        [controller, action] -> "\#{controller}/\#{action}"
      end
    end
  end

  labels: [:status_class, phoenix_controller: CustomLabels, phoenix_controller_action: {CustomLabels, :phoenix_controller_action}]
  ```

  Bear in mind that bounds are ***microseconds*** (1s is 1_000_000us)
  """

  alias Plug.Conn

  require Logger
  require Prometheus.Contrib.HTTP

  use Prometheus.Metric
  use Prometheus.Config, [labels: [:status_class, :method, :host, :scheme],
                          duration_buckets: Prometheus.Contrib.HTTP.microseconds_duration_buckets(),
                          registry: :default]

  @behaviour Plug

  def setup(opts \\ []) do
    if opts != [] do
      Logger.warn("Prometheus.PlugsInstrumenter: passing options to setup is deprecated. Please use application config.")
    end
    request_duration_buckets = Keyword.get(opts, :request_duration_buckets, Config.duration_buckets)
    labels = normalize_labels(Keyword.get(opts, :labels, Config.labels))
    registry = Keyword.get(opts, :registry, Config.registry)

    Counter.declare([name: :http_requests_total,
                     help: "Total number of HTTP requests made.",
                     labels: labels,
                     registry: registry])
    Histogram.declare([name: :http_request_duration_microseconds,
                       help: "The HTTP request latencies in microseconds.",
                       labels: labels,
                       buckets: request_duration_buckets,
                       registry: registry])
  end

  def init(labels) do
    labels = if labels != [] do
      Logger.warn("Prometheus.PlugsInstrumenter: passing options to plug is deprecated. Please use application config.")
      labels
    else
      Config.labels
    end

    if Enum.member?(labels, :code) do
      Logger.warn("Prometheus.PlugsInstrumenter: `code` label is deprecated. Probably can be replaced with `status_class`. Or if you still need numbers use `status_code`.")
    end
    labels
  end

  def call(conn, labels) do
    start = current_time()

    Conn.register_before_send(conn, fn conn ->
      labels = construct_labels(labels, conn)
      Counter.inc([registry: Config.registry,
                   name: :http_requests_total,
                   labels: labels])

      stop = current_time()
      diff = time_diff(start, stop)

      Histogram.observe([regsitry: Config.registry,
                         name: :http_request_duration_microseconds,
                         labels: labels], diff)

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

  defp normalize_labels(labels) do
    for label <- labels do
      case label do
        {name, _} -> name
        name -> name
      end
    end
  end

  defp construct_labels(labels, conn) do
    for label <- labels, do: label_value(label, conn)
  end

  defp label_value(:code, conn), do: conn.status
  defp label_value(:status_code, conn), do: conn.status
  defp label_value(:status_class, conn), do: Prometheus.Contrib.HTTP.status_class(conn.status)
  defp label_value(:method, conn), do: conn.method
  defp label_value(:host, conn), do: conn.host
  defp label_value(:scheme, conn), do: conn.scheme
  defp label_value(:port, conn), do: conn.port
  defp label_value({_label, {module, fun}}, conn), do: Kernel.apply(module, fun, [conn]) ## FIXME: replace with code generation
  defp label_value({label, module}, conn), do: Kernel.apply(module, :label_value, [label, conn]) ## FIXME: replace with code generation
end
