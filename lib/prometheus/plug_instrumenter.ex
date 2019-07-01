defmodule Prometheus.PlugInstrumenter do
  @moduledoc """
  Helps you create a plug that instruments another plug(s).

  Internally works like and uses Plug.Builder so can instrument many
  plugs at once. Just use regular plug macro!

  ### Usage

  1. Define your instrumenter:

  ```elixir
  defmodule EnsureAuthenticatedInstrumenter do
    use Prometheus.PlugInstrumenter

    plug Guardian.Plug.EnsureAuthenticated

    def label_value(:authenticated, {conn, _}) do
      conn.status != 401
    end
  end
  ```

  2. Configuration:

  ```elixir
  config :prometheus, EnsureAuthenticatedInstrumenter,
    counter: :guardian_ensure_authenticated_total,
    counter_help: "Total number of EnsureAuthenticated plug calls.",
    histogram: :guardian_ensure_authenticated_duration_microseconds,
    histogram_help: "Duration of EnsureAuthenticated plug calls.",
    labels: [:authenticated]
  ```

  3. Call `EnsureAuthenticatedInstrumenter.setup/0` when application starts
  (e.g. supervisor setup):

  ```elixir
  EnsureAuthenticatedInstrumenter.setup()
  ```

  4. Add `EnsureAuthenticatedInstrumenter` to your plug pipeline or replace
  `Guardian.Plug.EnsureAuthenticated` if it already present.

  ```elixir:
  plug EnsureAuthenticatedInstrumenter, handler: Guardian.Plug.ErrorHandler
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

  Plug pipeline instrumenter can be configured via `EnsureAuthenticatedInstrumenter` (you should replace this with the name
  of your plug) key of prometheus app env.

  Mandatory keys:
   - counter or histogram.

  Optional keys with defaults:

   - registry - Prometheus registry for metrics (:default);
   - counter - counter metric name (false);
   - counter_help - help string for counter metric ("");
   - histogram - histogram metric name (false);
   - histogram_help - help string for histogram metric ("");
   - histogram_buckets - histogram metric buckets (Prometheus.Contrib.HTTP.microseconds_duration_buckets());
   - labels - labels for counter and histogram ([]);
   - duration_units - duration units for the histogram, if histogram name already has known duration unit
     this can be omitted (:undefined).

  As noted above at least one metric name should be given. Of course you must tell what plug(s)
  to instrument.

  We don't have default labels because they are highly specific to a particular plug(s) hence default is [].

  Bear in mind that buckets are ***<duration_unit>*** so if you are not using default unit
  you also have to override buckets.
  """

  require Logger
  require Prometheus.Contrib.HTTP

  use Prometheus.Config,
    counter: false,
    counter_help: "",
    histogram: false,
    histogram_help: "",
    histogram_buckets: Prometheus.Contrib.HTTP.microseconds_duration_buckets(),
    labels: [],
    registry: :default,
    duration_unit: :undefined

  use Prometheus.Metric

  defmacro __using__(_opts) do
    module_name = __CALLER__.module

    counter = Config.counter(module_name)
    counter_help = Config.counter_help(module_name)
    histogram = Config.histogram(module_name)
    histogram_help = Config.histogram_help(module_name)
    histogram_buckets = Config.histogram_buckets(module_name)
    labels = Config.labels(module_name)
    nlabels = normalize_labels(labels)
    registry = Config.registry(module_name)
    duration_unit = Config.duration_unit(module_name)

    if !counter and !histogram do
      raise "No metrics!"
    end

    quote location: :keep do
      @behaviour Plug
      Module.register_attribute(__MODULE__, :plugs, accumulate: true)

      use Prometheus.Metric
      import Prometheus.PlugInstrumenter

      def setup() do
        unquote(
          if counter do
            quote do
              Counter.declare(
                name: unquote(counter),
                help: unquote(counter_help),
                labels: unquote(nlabels),
                registry: unquote(registry)
              )
            end
          end
        )

        unquote(
          if histogram do
            quote do
              Histogram.declare(
                name: unquote(histogram),
                help: unquote(histogram_help),
                labels: unquote(nlabels),
                buckets: unquote(histogram_buckets),
                registry: unquote(registry),
                duration_unit: unquote(duration_unit)
              )
            end
          end
        )
      end

      def init(opts) do
        opts
      end

      def call(conn, state) do
        unquote(
          if histogram do
            quote do
              start = :erlang.monotonic_time()
            end
          end
        )

        conn = call_pipeline(conn)

        unquote(
          if histogram do
            quote do
              diff = :erlang.monotonic_time() - start
            end
          end
        )

        labels = unquote(construct_labels(labels))

        unquote(
          if histogram do
            quote do
              Histogram.observe(
                [name: unquote(histogram), labels: labels, registry: unquote(registry)],
                diff
              )
            end
          end
        )

        unquote(
          if counter do
            quote do
              Counter.inc(
                name: unquote(counter),
                labels: labels,
                registry: unquote(registry)
              )
            end
          end
        )

        conn
      end

      @before_compile Prometheus.PlugInstrumenter
    end
  end

  @doc """
  Stores a plug to be instrumented.
  """
  defmacro plug(plug, opts \\ []) do
    quote do
      @plugs {unquote(plug), unquote(opts), true}
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    plugs = Module.get_attribute(env.module, :plugs)
    {conn, body} = Plug.Builder.compile(env, plugs, [])

    quote do
      defp call_pipeline(unquote(conn)), do: unquote(body)
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
