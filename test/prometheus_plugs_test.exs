defmodule PrometheusPlugsTest do
  use ExUnit.Case
  doctest Plug.PrometheusCollector
  doctest Plug.PrometheusExporter

  test "the truth" do
    assert 1 + 1 == 2
  end
end
