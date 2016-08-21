defmodule Prometheus.PlugsInstrumenter.Config do

  @default_labels [:status_class, :method, :host, :scheme]
  @default_duration_buckets :prometheus_http.microseconds_duration_buckets()
  @default_registry :default
  @default_config [labels: @default_labels,
                   duration_buckets: @default_duration_buckets,
                   registry: @default_registry]

  def labels do
    config(:labels, @default_labels)
  end

  def duration_buckets do
    config(:duration_buckets, @default_duration_buckets)
  end

  def config do
    Application.get_env(:prometheus, PlugsInstrumenter, @default_config)
  end
  
  def registry do
    config(:registry, @default_registry)
  end

  def config(name, default) do
    config
    |> Keyword.get(name, default)
  end
  
end
