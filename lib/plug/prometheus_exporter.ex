defmodule Plug.PrometheusExporter do
  @moduledoc """
  Exports metrics in text format via configurable endpoint:
  ``` elixir
  # on app startup (e.g. supervisor setup)
  Plug.PrometheusExporter.setup()

  # in your plugs pipeline
  plug Plug.PrometheusExporter, [path: "/prom/metrics"]  # default is /metrics
  ```

  Also maintains telemetry metrics:
   - telemetry_scrape_duration_seconds
   - telemetry_scrape_size_bytes

  Do not forget to call `setup/0,1` before using plug, for example on application start!

  Options:
   - path - url to scrape. Default is `"/metrics"`.
   - format - export format (`:prometheus_text_format` or `:prometheus_protobuf_format`). Default is `:prometheus_text_format`.
   - registry - prometheus registry to export. Default is `:default`.
  """

  import Plug.Conn
  @behaviour Plug

  def setup(_opts \\ []) do
    :prometheus_summary.declare([name: :telemetry_scrape_duration_seconds,
                                 help: "Scrape duration",
                                 labels: ["content_type"]])

    :prometheus_summary.declare([name: :telemetry_scrape_size_bytes,
                                 help: "Scrape size, uncompressed",
                                 labels: ["content_type"]])
  end

  def init(opts) do
    :prometheus.start
    path = Keyword.get(opts, :path, "/metrics")
    format = Keyword.get(opts, :format, :prometheus_text_format)
    registry = Keyword.get(opts, :registry, :default)
    {Plug.Router.Utils.split(path), format, registry}
  end

  def call(conn, {path, format, registry}) do
    case conn.path_info do
      ^path ->
        scrape = scrape_data(format, registry)
        conn
        |> put_resp_content_type(format.content_type)
        |> send_resp(200, scrape)
        |> halt
      _ ->
        conn
    end
  end

  defp scrape_data(format, registry) do
    scrape = :prometheus_summary.observe_duration(:telemetry_scrape_duration_seconds,
      [format.content_type],
      fn () -> format.format(registry) end)

    :prometheus_summary.observe(:telemetry_scrape_size_bytes,
      [format.content_type],
      :erlang.iolist_size(scrape))

    scrape
  end
end
