defmodule Prometheus.PlugInstrumenter do
  @moduledoc """
  Helps you create a plug that instruments another plug.

  ### Usage

  1. Define your instrumenter:

  ```elixir
  defmodule MyApp.Guardian.Plug.EnsureAuthenticatedInstrumenter do
    use Prometheus.PlugInstrumenter, [plug: Guardian.Plug.EnsureAuthenticated,
                                      counter: :guardian_ensure_authenticated_total,
                                      histogram: :guardian_ensure_authenticated_duration_microseconds,
                                      labels: [:authenticated]]

    def label_value(:authenticated, {conn, _}) do
      conn.status != 401
    end
  end

  2. Call `MyApp.Guardian.Plug.EnsureAuthenticatedInstrumenter.setup/0` when application starts
  (e.g. supervisor setup):

  ```elixir
  MyApp.Guardian.Plug.EnsureAuthenticatedInstrumenter.setup()
  ```

  3. Add `MyApp.Guardian.Plug.EnsureAuthenticatedInstrumenter` to your plug pipeline or replace
  `Guardian.Plug.EnsureAuthenticated` if it already present.

  ```elixir:
  plug MyApp.Guardian.Plug.EnsureAuthenticatedInstrumenter, handler: Guardian.Plug.ErrorHandler
  ```

  As you can see you can transparently pass options to the underlying plug.

  ### Metrics

  Currently PlugInstrumenter supports two metrics - counter for total calls count and
  histogram for calls duration. Metric can be disabled by setting it's name to false:

  ```elixir
  counter: false
  ```

  There should be at least one active metric.

  ### Configuration

  Mandatory keys:
   - plug - Plug to instrument;
   - counter or histogram.

  Optional keys with defaults:

   - registry - Prometheus registry for metrics (:default);
   - counter - counter metric name (false);
   - histogram - histogram metric name (false);
   - histogram_buckets - histogram metric buckets (Prometheus.Contrib.HTTP.microseconds_duration_buckets());
   - labels - labels for counter and histogram ([]).

  As noted above at least one metric name should be supplied. Of course you must tell what plug
  to instrument through `:plug` key.

  We don't have default labels because they are highly specific to a particular plug hence default is [].

  It's possible to customize histogram buckets via `:histogram_buckets` key. Bear in mind that bounds are ***microseconds*** (1s is 1_000_000us)
  """

  require Logger
  require Prometheus.Contrib.HTTP

  use Prometheus.Config, [:plug,
                          counter: false,
                          histogram: false,
                          histogram_buckets: Prometheus.Contrib.HTTP.microseconds_duration_buckets(),
                          labels: [],
                          registry: :default]

  use Prometheus.Metric

  defmacro __using__(_opts) do
    module_name = __CALLER__.module

    plug = Config.plug!(module_name)
    friendly_plug_name = String.replace_leading("#{plug}", "Elixir.", "")
    counter = Config.counter(module_name)
    histogram = Config.histogram(module_name)
    histogram_buckets = Config.histogram_buckets(module_name)
    labels = Config.labels(module_name)
    nlabels = normalize_labels(labels)
    registry = Config.registry(module_name)

    if !counter and !histogram do
      raise "No metrics!"
    end

    quote do

      use Prometheus.Metric

      def setup() do

        unquote(if counter do
          quote do
            Counter.declare([name: unquote(counter),
                             help: unquote("Total number of #{friendly_plug_name} plug calls."),
                             labels: unquote(nlabels),
                             registry: unquote(registry)])
          end
        end)

        unquote(if histogram do
          quote do
            Histogram.declare([name: unquote(histogram),
                               help: unquote("#{friendly_plug_name} plug calls duration in microseconds."),
                               labels: unquote(nlabels),
                               buckets: unquote(histogram_buckets),
                               registry: unquote(registry)])
          end
        end)

      end

      def init(opts) do
        unquote(plug).init(opts)
      end

      # TODO: remove this once Plug supports only Elixir 1.2.
      if function_exported?(:erlang, :monotonic_time, 0) do
        defp current_time, do: :erlang.monotonic_time
        defp time_diff(start, stop), do: (stop - start) |> :erlang.convert_time_unit(:native, :micro_seconds)
      else
        defp current_time, do: :os.timestamp()
        defp time_diff(start, stop), do: :timer.now_diff(stop, start)
      end

      def call(conn, state) do

        unquote(if histogram do
          quote do
            start = current_time()
          end
        end)

        conn = unquote(plug).call(conn, state)

        unquote(if histogram do
          quote do
            diff = (current_time - start) |> :erlang.convert_time_unit(:native, :micro_seconds)
          end
        end)

        labels = unquote(construct_labels(labels))

        unquote(if histogram do
          quote do
            Histogram.observe([name: unquote(histogram),
                               labels: labels,
                               registry: unquote(registry)],
              diff)
          end
        end)

        unquote(if counter do
          quote do
            Counter.inc([name: unquote(counter),
                         labels: labels,
                         registry: unquote(registry)])
          end
        end)

        conn

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

  defp label_value({label, {module, fun}}) do
    quote do
      unquote(module).unquote(fun)(unquote(label), {conn, state})
    end
  end
  defp label_value({label, module}) do
    quote do
      unquote(module).label_value(unquote(label), {conn, state})
    end
  end
  defp label_value(label) do
    quote do
      label_value(unquote(label), {conn, state})
    end
  end

end
