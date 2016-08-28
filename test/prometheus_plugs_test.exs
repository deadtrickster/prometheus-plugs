defmodule PrometheusPlugsTest do
  use ExUnit.Case
  use Plug.Test
  ## doctest Plug.PrometheusCollector
  ## doctest Plug.PrometheusExporter

  require Prometheus.Registry

  setup do
    Prometheus.Registry.clear(:default)
    Prometheus.Registry.clear(:qwe)

    Prometheus.TestPlugPipelineInstrumenter.setup()
    Prometheus.TestPlugPipelineInstrumenterCustomConfig.setup()
    Prometheus.TestPlugExporter.setup()
    Prometheus.TestPlugExporterCustomConfig.setup()

    :ok
  end

  use Prometheus.Metric

  test "the truth" do
    assert 1 + 1 == 2
  end


  defp call(conn) do
    Prometheus.TestPlugStack.call(conn, Prometheus.TestPlugStack.init([]))
  end

  test "Plug Pipeline Instrumenter tests" do
    conn = call(conn(:get, "/"))
    assert conn.resp_body == "Hello World!"

    assert 1 == Counter.value([name: :http_requests_total,
                               registry: :default,
                               labels: ['success', "GET", "www.example.com", :http]])

    assert 1 == Counter.value([name: :http_requests_total,
                               registry: :qwe,
                               labels: ["GET", 12]])

    assert {buckets, sum} = Histogram.value([name: :http_request_duration_microseconds,
                                             registry: :default,
                                             labels: ['success', "GET", "www.example.com", :http]])

    assert sum > 0
    assert 13 = length(buckets)
    assert 1 = Enum.reduce(buckets, fn(x, acc) -> x + acc end)

    assert {buckets, sum} = Histogram.value([name: :http_request_duration_microseconds,
                                             registry: :qwe,
                                             labels: ["GET", 12]])

    assert sum > 0
    assert 3 = length(buckets)
    assert 1 = Enum.reduce(buckets, fn(x, acc) -> x + acc end)
  end

  test "Plug Exporter tests" do
    conn = call(conn(:get, "/"))
    assert conn.resp_body == "Hello World!"

    call(conn(:get, "/metrics"))
    conn = call(conn(:get, "/metrics"))

    assert {_,_} = :binary.match(conn.resp_body,
      "http_request_duration_microseconds_bucket{status_class=\"success\",method=\"GET\",host=\"www.example.com\",scheme=\"http\",le=\"+Inf\"} 1")
    assert {_,_} = :binary.match(conn.resp_body,
      "telemetry_scrape_size_bytes_count{registry=\"default\",content_type=\"text/plain; version=0.0.4\"} 1")
    assert {_,_} = :binary.match(conn.resp_body,
      "telemetry_scrape_duration_seconds_count{registry=\"default\",content_type=\"text/plain; version=0.0.4\"} 1")

    call(conn(:get, "/metrics"))
    conn = call(conn(:get, "/metrics"))

    assert conn.resp_body > 0 ## TODO: decode and check protobuf resp body
  end
end
