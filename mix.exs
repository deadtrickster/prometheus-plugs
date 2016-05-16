defmodule PrometheusPlug.Mixfile do
  use Mix.Project

  def project do
    [app: :prometheus_plug,
     version: "0.0.1",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :prometheus]]
  end
  
  defp deps do    
    [{:cowboy, "~> 1.0.0"},
     {:plug, "~> 1.0"},
     {:prometheus, git: "https://github.com/deadtrickster/prometheus.erl.git"}]
  end
end
