defmodule Prometheus.PlugPipelineInstrumenter do
  @moduledoc """
  Plug for collecting http metrics.

  To use it, plug it into the desired module.
  You also want to call `setup/0` before using plug, for example on application start!

  plug Prometheus.PlugsInstrumenter

  Currently maintains two metrics.
   - `http_requests_total` - Total nubmer of HTTP requests made. This one is a counter.
   - `http_request_duration_microseconds` - The HTTP request latencies in microseconds. This one is a histogram.

  ```elixir
  # my_plug_pipeline_instrumenter.ex
  defmodule PlugPipelineInstrumenter do
    use Prometheus.PlugsInstrumenter
  end

  # on app startup (e.g. supervisor setup)
  PlugPipelineInstrumenter.setup()

  # in your plugs pipeline
  plug PlugPipelineInstrumenter
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
  config :prometheus, PlugPipelineInstrumenter,
    labels: [:status_class, :method, :host, :scheme],
    duration_buckets:[10, 100, 1_000, 10_000, 100_000,
                      300_000, 500_000, 750_000, 1_000_000,
                      1_500_000, 2_000_000, 3_000_000],
    registry: :default
  ```

  In fact almost any [Plug.Conn](https://hexdocs.pm/plug/Plug.Conn.html) field value can be used as metric label.
  In order to create a custom label simply provide a fun as either a key-value
  pair where the value is either module name with `label_value/2` function exported
  or `{module, fun/2}` tuple. By default target module's `label_value` is called when label is unknown.

  ``` elixir
  defmodule PlugPipelineInstrumenter do
    use Prometheus.PlugsInstrumenter

    def label_value(:request_path, conn) do
      conn.request_path
    end
  end

  labels: [:status_class, :request_path]
  ```

  Bear in mind that bounds are ***microseconds*** (1s is 1_000_000us)
  """

  require Logger
  require Prometheus.Contrib.HTTP

  use Prometheus.Metric
  use Prometheus.Config, [labels: [:status_class, :method, :host, :scheme],
                          duration_buckets: Prometheus.Contrib.HTTP.microseconds_duration_buckets(),
                          registry: :default]

  defmacro __using__(_opts) do    
    module_name = __CALLER__.module
    
    request_duration_buckets = Config.duration_buckets(module_name)
    labels = Config.labels(module_name)
    nlabels = normalize_labels(labels)
    registry = Config.registry(module_name)
    
    quote do

      @behaviour Plug
      alias Plug.Conn
      use Prometheus.Metric
      require Prometheus.Contrib.HTTP

      def setup() do

        Counter.declare([name: :http_requests_total,
                         help: "Total number of HTTP requests made.",
                         labels: unquote(nlabels),
                         registry: unquote(registry)])
        Histogram.declare([name: :http_request_duration_microseconds,
                           help: "The HTTP request latencies in microseconds.",
                           labels: unquote(nlabels),
                           buckets: unquote(request_duration_buckets),
                           registry: unquote(registry)])
      end

      def init(_opts) do
      end

      def call(conn, labels) do
        start = current_time()

        Conn.register_before_send(conn, fn conn ->
          labels = unquote(construct_labels(labels))

          Counter.inc([registry: unquote(registry),
                       name: :http_requests_total,
                       labels: labels])

          stop = current_time()
          diff = time_diff(start, stop)

          Histogram.observe([regsitry: unquote(registry),
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
    end
  end

  defp normalize_labels(labels) do
    for label <- labels do
      case label do
        {name, _} -> name
        name -> name
      end
    end
  end

  defp construct_labels(labels) do
    for label <- labels, do: label_value(label)
  end

  defp label_value(:code) do
    quote do
      conn.status
    end
  end
  defp label_value(:status_code) do
    quote do
      conn.status
    end
  end
  defp label_value(:status_class) do
    quote do
      Prometheus.Contrib.HTTP.status_class(conn.status)
    end
  end
  defp label_value(:method) do
    quote do
      conn.method
    end
  end
  defp label_value(:host) do
    quote do
      conn.host
    end
  end
  defp label_value(:scheme) do
    quote do
      conn.scheme
    end
  end
  defp label_value(:port) do
    quote do
      conn.port
    end
  end
  defp label_value({label, {module, fun}}) do
    quote do
      unquote(module).unquote(fun)(unquote(label), conn)
    end
  end
  defp label_value({label, module}) do
    quote do
      unquote(module).label_value(unquote(label), conn)
    end
  end
  defp label_value(label) do
    quote do
      label_value(unquote(label), conn)
    end
  end
end
