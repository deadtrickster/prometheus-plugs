defmodule Prometheus.PlugExporter do
  @moduledoc """
  Exports Prometheus metrics via configurable endpoint:

  ``` elixir
  # define plug
  defmodule MetricsPlugExporter do
    use Prometheus.PlugExporter
  end

  # on app startup (e.g. supervisor setup)
  MetricsPlugExporter.setup()

  # in your plugs pipeline
  plug MetricsPlugExporter
  ```

  **Do not add to Phoenix Router pipelines!** You will be getting 404!
  ```
  Note that router pipelines are only invoked after a route is found.
  No plug is invoked in case no matches were found.
  ```

  ### Metrics

  Also maintains telemetry metrics:
   - telemetry_scrape_duration_seconds
   - telemetry_scrape_size_bytes

  Do not forget to call `setup/0` before using plug, for example on application start!

  ### Configuration

  Plugs exporter can be configured via PlugsExporter key of `:prometheus` app env.

  Default configuration:

  ```elixir
  config :prometheus, MetricsPlugExporter, # (you should replace this with the name of your plug)
    path: "/metrics",
    format: :text,
    registry: :default
  ```
  """

  require Logger

  use Prometheus.Metric
  use Prometheus.Config, [path: "/metrics",
                          format: :text,
                          registry: :default]

  ## TODO: support multiple endpoints [for example separate endpoint for each registry]
  ##  endpoints: [[registry: :qwe,
  ##               path: "/metrics1"],
  ##              [registry: :default,
  ##               path: "/metrics",
  ##               format: :protobuf]]
  defmacro __using__(_opts) do
    module_name = __CALLER__.module

    registry = Config.registry(module_name)
    path = Plug.Router.Utils.split(Config.path(module_name))
    format = normalize_format(Config.format(module_name))

    content_type = format.content_type
    labels = [registry, format.content_type]

    quote do

      @behaviour Plug
      import Plug.Conn
      use Prometheus.Metric

      def setup() do
        Summary.declare([name: :telemetry_scrape_duration_seconds,
                         help: "Scrape duration",
                         labels: ["registry", "content_type"],
                         registry: unquote(registry)])

        Summary.declare([name: :telemetry_scrape_size_bytes,
                         help: "Scrape size, uncompressed",
                         labels: ["registry", "content_type"],
                         registry: unquote(registry)])
      end

      def init(_opts) do
      end

      def call(conn, _opts) do
        case conn.path_info do
          unquote(path) ->
            scrape = scrape_data()
            conn
            |> put_resp_content_type(unquote(content_type), nil)
            |> send_resp(200, scrape)
            |> halt
          _ ->
            conn
        end
      end

      defp scrape_data do
        scrape = Summary.observe_duration(
          [registry: unquote(registry),
           name: :telemetry_scrape_duration_seconds,
           labels: unquote(labels)],
          fn () ->
            unquote(format).format(unquote(registry))
          end)

        Summary.observe(
          [registry: unquote(registry),
           name: :telemetry_scrape_size_bytes,
           labels: unquote(labels)],
          :erlang.iolist_size(scrape))

        scrape
      end
    end
  end

  defp normalize_format(:text), do: :prometheus_text_format
  defp normalize_format(:protobuf), do: :prometheus_protobuf_format
  defp normalize_format(Prometheus.Format.Text), do: :prometheus_text_format
  defp normalize_format(Prometheus.Format.Protobuf), do: :prometheus_protobuf_format
  defp normalize_format(format), do: format
end
