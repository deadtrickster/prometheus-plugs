defmodule Plug.PrometheusExporter do
  @moduledoc """
  Exports metrics in text format via configurable endpoint:
  ``` elixir
  plug Plug.PrometheusExporter, [path: "/prom/metrics"]  # default is /metrics
  ```
  """

  import Plug.Conn
  @behaviour Plug

  def init(opts) do
    :prometheus.start
    path = Keyword.get(opts, :path, "/metrics")
    registry = Keyword.get(opts, :registry, :default)
    {Plug.Router.Utils.split(path), registry}
  end

  def call(conn, {path, registry}) do

    case conn.path_info do
      ^path ->
        conn
        |> put_resp_content_type(:prometheus_text_format.content_type)
        |> send_resp(200, :prometheus_text_format.format(registry))
        |> halt
      _ ->
        conn
    end
  end
end
