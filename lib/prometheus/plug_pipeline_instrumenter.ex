defmodule Prometheus.PlugPipelineInstrumenter do
  @moduledoc """
  Generates a plug for collecting http metrics. Instruments whole pipeline.

  First lets define plug for your instrumenter:

  ```elixir
  defmodule PlugPipelineInstrumenter do
    use Prometheus.PlugPipelineInstrumenter
  end
  ```

  Then add call `setup/0` before using plug, for example on application start!

  ```elixir
  # on app startup (e.g. supervisor setup)
  PlugPipelineInstrumenter.setup()
  ```

  And finally add plug to pipeline:
  ```elixir
  # in your plug pipeline
  plug PlugPipelineInstrumenter
  ```

  ### Metrics

  Currently maintains two metrics.
   - `http_requests_total` - Total nubmer of HTTP requests made. This one is a counter.
   - `http_request_duration_<duration_unit>` - The HTTP request latencies in <duration_unit>. This one is a histogram.

  ### Configuration

  Plug pipeline instrumenter can be configured via `PlugPipelineInstrumenter` (you should replace this with the name
  of your plug) key of prometheus app env.

  All metrics support configurable labels:

  ```
   - status_code - http code;
   - status_class - http code class, like "success", "redirect", "client-error", etc;
   - method - http method;
   - host - requested host;
   - port - requested port;
   - scheme - request scheme (like http or https).
  ```

  Default configuration:

  ```elixir
  config :prometheus, PlugPipelineInstrumenter,
    labels: [:status_class, :method, :host, :scheme],
    duration_buckets: [10, 100, 1_000, 10_000, 100_000,
                       300_000, 500_000, 750_000, 1_000_000,
                       1_500_000, 2_000_000, 3_000_000],
    registry: :default,
    duration_unit: :microseconds
  ```

  Available duration units:
   - microseconds;
   - milliseconds;
   - seconds;
   - minutes;
   - hours;
   - days.

  In fact almost any [Plug.Conn](https://hexdocs.pm/plug/Plug.Conn.html) field value can be used as metric label.
  Label value can be generated using custom function. In order to create a custom label simply provide a fun reference
  as a key-value pair where key is a label name and value is either module name which exports `label_value/2` function
  or `{module, fun/2}` tuple. By default your plug's `label_value` is called when label is unknown.

  ``` elixir
  defmodule PlugPipelineInstrumenter do
    use Prometheus.PlugPipelineInstrumenter

    def label_value(:request_path, conn) do
      conn.request_path
    end
  end

  labels: [:status_class, :request_path]
  ```

  Bear in mind that buckets are ***<duration_unit>*** so if you are not using default unit
  you also have to override buckets.
  """

  ## TODO: instrumenter for single plug(decorator)

  require Logger

  require Prometheus.Contrib.HTTP

  use Prometheus.Metric

  use Prometheus.Config,
    labels: [:status_class, :method, :host, :scheme],
    duration_buckets: Prometheus.Contrib.HTTP.microseconds_duration_buckets(),
    registry: :default,
    duration_unit: :microseconds

  defmacro __using__(_opts) do
    module_name = __CALLER__.module

    request_duration_buckets = Config.duration_buckets(module_name)
    labels = Config.labels(module_name)
    nlabels = normalize_labels(labels)
    registry = Config.registry(module_name)
    duration_unit = Config.duration_unit(module_name)
    time_unit = time_unit(duration_unit)

    quote do
      @behaviour Plug
      alias Plug.Conn
      use Prometheus.Metric
      require Prometheus.Contrib.HTTP

      def setup() do
        Counter.declare(
          name: :http_requests_total,
          help: "Total number of HTTP requests made.",
          labels: unquote(nlabels),
          registry: unquote(registry)
        )

        Histogram.declare(
          name: unquote(:"http_request_duration_#{duration_unit}"),
          help: "The HTTP request latencies in #{unquote(duration_unit)}.",
          labels: unquote(nlabels),
          buckets: unquote(request_duration_buckets),
          registry: unquote(registry)
        )
      end

      def init(_opts) do
      end

      def call(conn, labels) do
        start = :erlang.monotonic_time(unquote(time_unit))

        Conn.register_before_send(conn, fn conn ->
          labels = unquote(construct_labels(labels))

          Counter.inc(
            registry: unquote(registry),
            name: :http_requests_total,
            labels: labels
          )

          stop = :erlang.monotonic_time(unquote(time_unit))

          diff = stop - start

          Histogram.observe(
            [
              registry: unquote(registry),
              name: unquote(:"http_request_duration_#{duration_unit}"),
              labels: labels
            ],
            diff
          )

          conn
        end)
      end
    end
  end

  defp time_unit(:microseconds), do: :microsecond
  defp time_unit(:milliseconds), do: :millisecond
  defp time_unit(:seconds), do: :second
  defp time_unit(_other), do: :second

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
