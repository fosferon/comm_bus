defmodule CommBus.MixProject do
  use Mix.Project

  def project do
    [
      app: :comm_bus,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {CommBus.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bbmustache, "~> 1.12"},
      {:ex_mustache, "~> 0.2.0"},
      {:yaml_elixir, ">= 2.11.0 and < 3.0.0"},
      {:file_system, "~> 1.1"},
      {:alf, "~> 0.12"},
      {:ecto, "~> 3.11"},
      {:telemetry_metrics, "~> 0.6"},
      {:stream_data, "~> 0.6", only: :test}
    ]
  end
end
