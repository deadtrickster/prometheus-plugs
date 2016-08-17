defmodule PrometheusPlugs.Mixfile do
  use Mix.Project

  @version "0.8.0"

  def project do
    [app: :prometheus_plugs,
     version: @version,
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     description: description,
     package: package,
     docs: [extras: ["README.md"], main: "readme",
            source_ref: "v#{@version}",
            source_url: "https://github.com/deadtrickster/prometheus-plugs"]]
  end

  def application do
    [applications: [:logger, :prometheus]]
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
              "Example App" => "https://github.com/deadtrickster/prometheus-plugs-example"}]
  end

  defp deps do
    [{:cowboy, "~> 1.0.0"},
     {:plug, "~> 1.0"},
     {:prometheus, "~> 2.0"},
     {:ex_doc, "~> 0.11", only: :dev},
     {:earmark, ">= 0.0.0", only: :dev},
     {:prometheus_process_collector, "~> 0.2", optional: true}]
end
end
