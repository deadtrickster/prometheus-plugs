# Prometheus.io Plugs Instrumenter/Exporter
[![Hex.pm](https://img.shields.io/hexpm/v/prometheus_plugs.svg?maxAge=2592000?style=plastic)](https://hex.pm/packages/prometheus_plugs) [![Build Status](https://travis-ci.org/deadtrickster/prometheus-plugs.svg?branch=master)](https://travis-ci.org/deadtrickster/prometheus-plugs)  [![Documentation](https://img.shields.io/badge/documentation-on%20hexdocs-green.svg)](https://hexdocs.pm/prometheus_plugs/1.0.0-rc1/)

Elixir Plug integration for [prometheus.ex](https://github.com/deadtrickster/prometheus.ex)

***TL;DR*** [Example app](https://github.com/deadtrickster/prometheus-plugs-example)

### Instrumentation

To instrument whole plug pipeline use `Prometheus.PlugPipelineInstrumenter`:

```elixir
defmodule MyApp.Endpoint.PipelineInstrumenter do
  use Prometheus.PlugPipelineInstrumenter
end
```

To instrument just a single plug use `Prometheus.PlugInstrumenter`:

```elixir
defmodule MyApp.CoolPlugInstrumenter do
  use Prometheus.PlugInstrumenter, [plug: Guardian.Plug.EnsureAuthenticated,
                                    counter: :guardian_ensure_authenticated_total,
                                    histogram: :guardian_ensure_authenticated_duration_microseconds,
                                    labels: [:authenticated]]
end
```

Both modules implement plug interface and `Prometheus.PlugInstrumenter` generates proxy for specified plug so you'll need to replace instrumented plug with your instrumenter in pipeline.

Instrumenters configured via `:prometheus` app environment. Please consult respective modules documentation on
what options are available.

### Exporting

To export metric we first have to create a plug that will serve scraping requests.

```elixir
defmodule MyApp.MetricsExporter do
  use Prometheus.PlugExporter
end
```

Then we add exporter to MyApp pipeline:

```elixir
plug MyApp.MetricsExporter
```

You can configure path, export format and Prometheus registry via `:prometheus` app environment. For more information please see `Prometheus.PlugExporter` module documenataion.

## Integrations / Collectors / Instrumenters
 - [Ecto collector](https://github.com/deadtrickster/prometheus-ecto)
 - [Plugs Instrumenter/Exporter](https://github.com/deadtrickster/prometheus-plugs)
 - [Elli middleware](https://github.com/elli-lib/elli_prometheus)
 - [Fuse plugin](https://github.com/jlouis/fuse#fuse_stats_prometheus)
 - [Phoenix instrumenter](https://github.com/deadtrickster/prometheus-phoenix)
 - [Process Info Collector](https://github.com/deadtrickster/prometheus_process_collector.erl)
 - [RabbitMQ Exporter](https://github.com/deadtrickster/prometheus_rabbitmq_exporter)

## Installation

The package can be installed as:

  1. Add prometheus_plug to your list of dependencies in `mix.exs`:

        def deps do
          [{:prometheus_plugs, "~> 1.0.0-alpha8"}]
        end

  2. Ensure prometheus is started before your application:

        def application do
          [applications: [:prometheus]]
        end


## License

MIT
