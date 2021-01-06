# Prometheus.io Plugs Instrumenter/Exporter

[![Build Status](https://travis-ci.org/deadtrickster/prometheus-plugs.svg?branch=master)](https://travis-ci.org/deadtrickster/prometheus-plugs)
[![Module version](https://img.shields.io/hexpm/v/prometheus_plugs.svg?maxAge=2592000?style=plastic)](https://hex.pm/packages/prometheus_plugs)
[![Documentation](https://img.shields.io/badge/hex-docs-green.svg)](https://hexdocs.pm/prometheus_plugs/)
[![Total Download](https://img.shields.io/hexpm/dt/prometheus_plugs.svg?maxAge=2592000)](https://hex.pm/packages/prometheus_plugs)
[![License](https://img.shields.io/hexpm/l/prometheus_plugs.svg?maxAge=259200)](https://github.com/deadtrickster/prometheus-plugs/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/deadtrickster/prometheus-plugs.svg)](https://github.com/deadtrickster/prometheus-plugs/commits/master)

Elixir Plug integration for [prometheus.ex](https://github.com/deadtrickster/prometheus.ex)

Quick introduction by [**@skosch**](https://github.com/skosch): [Monitoring Elixir apps in 2016: Prometheus/Grafana Step-by-Step Guide](https://aldusleaf.org/2016-09-30-monitoring-elixir-apps-in-2016-prometheus-and-grafana.html)

 - IRC: #elixir-lang on Freenode;
 - [Slack](https://elixir-slackin.herokuapp.com/): #prometheus channel - [Browser](https://elixir-lang.slack.com/messages/prometheus) or App(slack://elixir-lang.slack.com/messages/prometheus).

## Instrumentation

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

## Exporting

To export metric we first have to create a plug that will serve scraping requests.

```elixir
defmodule MyApp.MetricsExporter do
  use Prometheus.PlugExporter
end
```

Call the `MyApp.MetricsExporter.setup/0` function when the application starts.

```elixir
# e.g. in `application.ex`
MyApp.MetricsExporter.setup()
```

Then we add exporter to MyApp pipeline:

```elixir
plug MyApp.MetricsExporter
```

You can configure path, export format and Prometheus registry via `:prometheus` app environment.
For more information please see `Prometheus.PlugExporter` module documentation.

Export endpoint can be secured using HTTP Basic Authentication:

```elixir
  auth: {:basic, "username", "password"}
```

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

1.  Add `:prometheus_plug` to your list of dependencies in `mix.exs`:
    ```elixir
    def deps do
      [{:prometheus_plugs, "~> 1.1.1"}]
    end
    ```

2.  Ensure prometheus is started before your application:
    ``` elixir
    def application do
      [applications: [:prometheus_plugs]]
    end
    ```

## License

This project is licensed under the MIT license. Copyright (c) 2016-present, Ilya Khaprov.
