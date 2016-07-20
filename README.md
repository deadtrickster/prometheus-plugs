# Prometheus Plugs [![Hex.pm](https://img.shields.io/hexpm/v/prometheus_plugs.svg?maxAge=2592000?style=plastic)](https://hex.pm/packages/prometheus_plugs)

Elixir plugs for [prometheus.erl](https://github.com/deadtrickster/prometheus.erl)

***TL;DR*** [Example app](https://github.com/deadtrickster/prometheus-plugs-example)

## Plugs

Prometheus Plugs currently comes with two Plugs. One is for collecting http metrics while another provides endpoint for scraping by Prometheus daemon.

#### Plug.PrometheusCollector
Currently maintains two metrics.
 - `http_requests_total` - Total nubmer of HTTP requests made. This one is a counter.
 - `http_request_duration_microseconds` - The HTTP request latencies in microseconds. This one is a histogram.

All metrics support configurable labels:
```elixir
Plug.PrometheusCollector.setup([:method, :host])
plug Plug.PrometheusCollector, [:method, :host]
```
Supported labels include:
 - code - http code
 - method - http method
 - host - requested host
 - port - requested port
 - scheme - request scheme (like http or https)

In fact almost any [Plug.Conn](https://hexdocs.pm/plug/Plug.Conn.html) field value can be used as metric label. Just throw PR if something is needed.

Additionaly `http_request_duration_microseconds` supports configurable bucket bounds:
```elixir
Plug.PrometheusCollector.setup([labels: [:method, :host],
                                 request_duration_bounds: [10, 100, 1_000, 10_000, 100_000, 300_000, 500_000, 750_000, 1_000_000, 1_500_000, 2_000_000, 3_000_000]])

plug Plug.PrometheusCollector, [:method, :host]
```

Bear in mind that bounds are ***microseconds*** (1s is 1_000_000us)

#### Plug.PrometheusExporter

Exports metrics in text format via configurable endpoint:
``` elixir
plug Plug.PrometheusExporter, [path: "/prom/metrics"]  # default is /metrics
```

## Installation

The package can be installed as:

  1. Add prometheus_plug to your list of dependencies in `mix.exs`:

        def deps do
          [{:prometheus_plugs, "~> 0.3.0"}]
        end

  2. Ensure prometheus is started before your application:

        def application do
          [applications: [:prometheus]]
        end


## License

MIT
