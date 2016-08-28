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

defmodule Prometheus.TestPlugExporterCustomConfig do
  use Prometheus.PlugExporter
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

  plug Prometheus.TestPlugPipelineInstrumenter
  plug Prometheus.TestPlugPipelineInstrumenterCustomConfig
  plug Prometheus.TestPlugExporter
  plug Prometheus.TestPlugExporterCustomConfig
  plug HelloWorldPlug, []
end
