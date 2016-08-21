# Prometheus Plugs [![Hex.pm](https://img.shields.io/hexpm/v/prometheus_plugs.svg?maxAge=2592000?style=plastic)](https://hex.pm/packages/prometheus_plugs)

Elixir plugs for [prometheus.erl](https://github.com/deadtrickster/prometheus.erl)

***TL;DR*** [Example app](https://github.com/deadtrickster/prometheus-plugs-example)

## Plugs

Prometheus Plugs currently comes with two Plugs. One is for collecting http metrics while another provides endpoint for scraping by Prometheus daemon.

#### Prometheus.PlugsInstrumenter

Currently maintains two metrics.
 - `http_requests_total` - Total nubmer of HTTP requests made. This one is a counter.
 - `http_request_duration_microseconds` - The HTTP request latencies in microseconds. This one is a histogram.
 
Setup

```elixir
# on app startup (e.g. supervisor setup)
Prometheus.PlugsInstrumenter.setup()

# in your plugs pipeline
plug Prometheus.PlugsInstrumenter
```

Plugs instrumenter can be configured via PlugsInstrumenter key of prometheus app env.

All metrics support configurable labels:

 - status_code - http code
 - status_class - http code class, like "success", "redirect", "client-error", etc
 - method - http method
 - host - requested host
 - port - requested port
 - scheme - request scheme (like http or https)

Default configuration:

```elixir
config :prometheus, PlugsInstrumenter,
  labels: [:status_class, :method, :host, :scheme],
  duration_buckets:[10, 100, 1_000, 10_000, 100_000,
                    300_000, 500_000, 750_000, 1_000_000,
                    1_500_000, 2_000_000, 3_000_000],
  registry: :default
```

In fact almost any [Plug.Conn](https://hexdocs.pm/plug/Plug.Conn.html) field value can be used as metric label.
In order to create a custom label simply provide a fun as either a key-value
pair where the value is a fun which will be given the label and conn as
parameters:

``` elixir
defmodule CustomLabels do
  def label_value(key, conn) do
    Map.get(conn.private, key, "unknown") |> to_string
  end

  def phoenix_controller_action(%Plug.Conn{private: private}) do
    case [private[:phoenix_controller], private[:phoenix_action]] do
      [nil, nil] -> "unknown"
      [controller, action] -> "#{controller}/#{action}"
    end
  end
end

labels: [:status_class, phoenix_controller: CustomLabels, phoenix_controller_action: {CustomLabels, :phoenix_controller_action}]
```

Bear in mind that bounds are ***microseconds*** (1s is 1_000_000us)

#### Plug.PrometheusExporter

Exports metrics in text format via configurable endpoint:

```elixir
# on app startup (e.g. supervisor setup)
Plug.PrometheusExporter.setup()

# in your plugs pipeline
plug Plug.PrometheusExporter
```

Defautl Configuration:

```elixir
config :prometheus, PlugsExporter,
  path: "/metrics",
  format: :text,
  registry: :default
```

## Installation

The package can be installed as:

  1. Add prometheus_plug to your list of dependencies in `mix.exs`:

        def deps do
          [{:prometheus_plugs, "~> 0.7"}]
        end

  2. Ensure prometheus is started before your application:

        def application do
          [applications: [:prometheus]]
        end


## License

MIT
