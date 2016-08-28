ExUnit.start()

defmodule Prometheus.TestPlugPipelineInstrumenter do
  use Prometheus.PlugPipelineInstrumenter
end

Application.put_env(:prometheus, Prometheus.TestPlugPipelineInstrumenterCustomConfig,
  labels: [:method, :resp_length],
  duration_buckets: [10, 100],
  registry: :qwe)

defmodule Prometheus.TestPlugPipelineInstrumenterCustomConfig do
  use Prometheus.PlugPipelineInstrumenter

  defp label_value(:resp_length, conn) do
    String.length(conn.resp_body)
  end
end

defmodule Prometheus.TestPlugExporter do
  use Prometheus.PlugExporter
end

Application.put_env(:prometheus, Prometheus.TestPlugExporterCustomConfig,
  format: :protobuf,
  path: "/metrics_qwe",
  registry: :qwe)

defmodule Prometheus.TestPlugExporterCustomConfig do
  use Prometheus.PlugExporter
end

defmodule Prometheus.VeryImportantPlug do

  import Plug.Conn

  def init(_opts) do
  end

  def call(conn, _opts) do
    case conn.path_info do
      ["qwe", "qwe"] ->
        put_private(conn, :vip_kind, :qwe)
      _ ->
        put_private(conn, :vip_kind, :other)
    end
  end

end

Application.put_env(:prometheus, Prometheus.VeryImportantPlugCounter,
  plug: Prometheus.VeryImportantPlug,
  counter: :vip_only_counter,
  labels: [:vip_kind])

defmodule Prometheus.VeryImportantPlugCounter do
  use Prometheus.PlugInstrumenter

  def label_value(:vip_kind, {conn, _}) do
    conn.private[:vip_kind]
  end
end

Application.put_env(:prometheus, Prometheus.VeryImportantPlugHistogram,
  plug: Prometheus.VeryImportantPlugCounter,
  histogram: :vip_only_histogram,
  labels: [:vip_kind],
  histogram_buckets: [100, 200],
  registry: :qwe)

defmodule Prometheus.VeryImportantPlugHistogram do
  use Prometheus.PlugInstrumenter

  def label_value(:vip_kind, {conn, _}) do
    conn.private[:vip_kind]
  end
end

Application.put_env(:prometheus, Prometheus.VeryImportantPlugInstrumenter,
  plug: Prometheus.VeryImportantPlugHistogram,
  counter: :vip_counter,
  histogram: :vip_histogram)

defmodule Prometheus.VeryImportantPlugInstrumenter do
  use Prometheus.PlugInstrumenter
end

defmodule HelloWorldPlug do
  import Plug.Conn

  def init(options) do
    # initialize options

    options
  end

  def call(conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "Hello World!")
  end
end

defmodule Prometheus.TestPlugStack do
  use Plug.Builder

  plug Prometheus.TestPlugExporter
  plug Prometheus.TestPlugExporterCustomConfig
  plug Prometheus.TestPlugPipelineInstrumenter
  plug Prometheus.TestPlugPipelineInstrumenterCustomConfig
  plug Prometheus.VeryImportantPlugInstrumenter
  plug HelloWorldPlug
end
