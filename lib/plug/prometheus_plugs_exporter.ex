defmodule Prometheus.PlugsExporter do
  @moduledoc """
  Exports metrics in text format via configurable endpoint:
  ``` elixir
  # on app startup (e.g. supervisor setup)
  Prometheus.PlugsExporter.setup()

  # in your plugs pipeline
  plug Prometheus.PlugsExporter
  ```

  Also maintains telemetry metrics:
   - telemetry_scrape_duration_seconds
   - telemetry_scrape_size_bytes

  Do not forget to call `setup/0` before using plug, for example on application start!

  ### Configuration
  
  Plugs exporter can be configured via PlugsExporter key of prometheus app env.

  Default configuration:  
  
  ```elixir
  
  config :prometheus, PlugsExporter,
    path: "/metrics",
    format: :text,
    registry: :default
  ```
  """

  import Plug.Conn
  require Logger
  alias Prometheus.PlugsExporter.Config
  @behaviour Plug

  ## TODO: support multiple endpoints [for example separate endpoint for each registry]
  ## via :endpoints config entry [{path, registry, format}]. Must wait till codegeneration implemented.
  def setup(_opts \\ []) do    
    :prometheus_summary.declare([name: :telemetry_scrape_duration_seconds,
                                 help: "Scrape duration",
                                 labels: ["content_type"]], Config.registry)

    :prometheus_summary.declare([name: :telemetry_scrape_size_bytes,
                                 help: "Scrape size, uncompressed",
                                 labels: ["content_type"]], Config.registry)
  end

  def init(opts) do
    opts = if opts != [] do
      Logger.warn("Prometheus.PlugsInstrumenter: passing options to plug is deprecated. Please use application config.")
      opts
    else
      Config.config
    end
    path = Keyword.get(opts, :path, Config.path)
    format = normalize_format(Keyword.get(opts, :format, Config.format))
    registry = Keyword.get(opts, :registry, Config.registry)
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

  defp normalize_format(:text), do: :prometheus_text_format
  defp normalize_format(:protobuf), do: :prometheus_protobuf_format
  defp normalize_format(format), do: format
  
  defp scrape_data(format, registry) do
    scrape = :prometheus_summary.observe_duration(:telemetry_scrape_duration_seconds,
      registry,
      [format.content_type],
      fn () -> format.format(registry) end)

    :prometheus_summary.observe(registry,
      :telemetry_scrape_size_bytes,
      [format.content_type],
      :erlang.iolist_size(scrape))

    scrape
  end
end
