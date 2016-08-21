defmodule Prometheus.PlugsExporter.Config do

  @default_path "/metrics"
  @default_format :text
  @default_registry :default
  @default_config [path: @default_path,
                   format: @default_format,
                   registry: @default_registry]

  def path do
    config(:path, @default_path)
  end

  def format do
    config(:format, @default_format)
  end

  def registry do
    config(:registry, @default_registry)
  end

  def config do
    Application.get_env(:prometheus, PlugsExporter, @default_config)
  end

  def config(name, default) do
    config
    |> Keyword.get(name, default)
  end
  
end
