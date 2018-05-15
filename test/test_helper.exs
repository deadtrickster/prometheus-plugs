ExUnit.start()
:application.ensure_all_started(:plug)

defmodule Prometheus.TestPlugPipelineInstrumenter do
  use Prometheus.PlugPipelineInstrumenter
end

Application.put_env(
  :prometheus,
  Prometheus.TestPlugPipelineInstrumenterCustomConfig,
  labels: [:method, :resp_length],
  duration_buckets: [10, 100],
  registry: :qwe,
  duration_unit: :seconds
)

defmodule Prometheus.TestPlugPipelineInstrumenterCustomConfig do
  use Prometheus.PlugPipelineInstrumenter

  defp label_value(:resp_length, conn) do
    String.length(conn.resp_body)
  end
end

defmodule Prometheus.TestPlugExporter do
  use Prometheus.PlugExporter
end

Application.put_env(
  :prometheus,
  Prometheus.TestPlugExporterCustomConfig,
  format: :protobuf,
  path: "/metrics_qwe",
  registry: :qwe,
  auth: {:basic, "qwe", "qwe"}
)

defmodule Prometheus.TestPlugExporterCustomConfig do
  use Prometheus.PlugExporter
end

defmodule Prometheus.VeryImportantPlug do
  import Plug.Conn

  def init(sleep) do
    sleep
  end

  def call(conn, sleep) do
    case conn.path_info do
      ["qwe", "qwe"] ->
        Process.sleep(sleep)
        put_private(conn, :vip_kind, :qwe)

      _ ->
        put_private(conn, :vip_kind, :other)
    end
  end
end

Application.put_env(
  :prometheus,
  Prometheus.VeryImportantPlugCounter,
  counter: :vip_only_counter,
  labels: [:vip_kind]
)

defmodule Prometheus.VeryImportantPlugCounter do
  use Prometheus.PlugInstrumenter

  plug(Prometheus.VeryImportantPlug, 1000)
  plug(Plug.RequestId)

  def label_value(:vip_kind, {conn, _}) do
    conn.private[:vip_kind]
  end
end

Application.put_env(
  :prometheus,
  Prometheus.VeryImportantPlugHistogram,
  histogram: :vip_only_histogram_microseconds,
  labels: [:vip_kind],
  histogram_buckets: [100, 200],
  registry: :qwe
)

defmodule Prometheus.VeryImportantPlugHistogram do
  use Prometheus.PlugInstrumenter

  plug(Prometheus.VeryImportantPlugCounter)

  def label_value(:vip_kind, {conn, _}) do
    conn.private[:vip_kind]
  end
end

Application.put_env(
  :prometheus,
  Prometheus.VeryImportantPlugInstrumenter,
  counter: :vip_counter,
  histogram: :vip_histogram,
  duration_unit: :seconds
)

defmodule Prometheus.VeryImportantPlugInstrumenter do
  use Prometheus.PlugInstrumenter

  plug(Prometheus.VeryImportantPlugHistogram)
end

defmodule HelloWorldPlug do
  import Plug.Conn

  def init(options) do
    # initialize options

    options
  end

  def call(conn, _opts) do
    Process.sleep(1000)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "Hello World!")
  end
end

defmodule Prometheus.TestPlugStack do
  use Plug.Builder

  plug(Prometheus.TestPlugExporter)
  plug(Prometheus.TestPlugExporterCustomConfig)
  plug(Prometheus.TestPlugPipelineInstrumenter)
  plug(Prometheus.TestPlugPipelineInstrumenterCustomConfig)
  plug(Prometheus.VeryImportantPlugInstrumenter)
  plug(HelloWorldPlug)
end
