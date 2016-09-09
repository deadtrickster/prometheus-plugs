defmodule PrometheusPlugs.Mixfile do
  use Mix.Project

  @version "1.0.0-alpha8"

  def project do
    [app: :prometheus_plugs,
     version: @version,
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     description: description,
     package: package,
     docs: [main: "api-reference",
            source_ref: "v#{@version}",
            source_url: "https://github.com/deadtrickster/prometheus-plugs"]]
  end

  def application do
    [applications: [:logger, :prometheus_ex]]
  end

  defp description do
    """
    Prometheus monitoring system client Plugs. Http metrics collector and exporter.
    """
  end

  defp package do
    [maintainers: ["Ilya Khaprov"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/deadtrickster/prometheus-plugs",
              "Prometheus.erl" => "https://hex.pm/packages/prometheus",
              "Prometheus.ex" => "https://hex.pm/packages/prometheus_ex",
              "Ecto Instrumenter" => "https://hex.pm/packages/prometheus_ecto",
              "Phoenix Instrumenter" => "https://hex.pm/packages/prometheus_phoenix",
              "Process info Collector" => "https://hex.pm/packages/prometheus_process_collector"}]
  end

  defp deps do
    [{:cowboy, "~> 1.0.0"},
     {:plug, "~> 1.0"},
     {:ex_doc, "~> 0.11", only: :dev},
     {:earmark, ">= 0.0.0", only: :dev},
     {:prometheus_ex, "~> 1.0.0-alpha8"},
     {:prometheus_process_collector, "~> 1.0.0-alpha8", optional: true}]
  end
end
