# Prometheus Plugs

Elixir plugs for [prometheus.erl](https://github.com/deadtrickster/prometheus.erl)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add prometheus_plug to your list of dependencies in `mix.exs`:

        def deps do
          [{:prometheus_plugs, "~> 0.0.1"}]
        end

  2. Ensure prometheus_plug is started before your application:

        def application do
          [applications: [:prometheus_plugs]]
        end

