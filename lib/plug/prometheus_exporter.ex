defmodule Plug.PrometheusExporter do
  @moduledoc """
  Exports metrics in text format via configurable endpoint:
  ``` elixir
  plug Plug.PrometheusExporter, [path: "/prom/metrics"]  # default is /metrics
  ```

  Options:
  - path - url to scrape. Default is `"/metrics".
  - format - export format (`:prometheus_text_format` or `:prometheus_protobuf_format`). Default is `:prometheus_text_format`.
  - registry - prometheus registry to export. Default is `:default`.
  """

  import Plug.Conn
  @behaviour Plug

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
        conn
        |> put_resp_content_type(format.content_type)
        |> send_resp(200, format.format(registry))
        |> halt
      _ ->
        conn
    end
  end
end
