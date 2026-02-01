defmodule CommBus.MixProject do
  use Mix.Project

  def project do
    [
      app: :comm_bus,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex metadata
      name: "CommBus",
      description:
        "Conversational context assembly for LLM interactions with keyword-triggered entry injection and token budget management",
      source_url: "https://github.com/fosferon/comm_bus",
      homepage_url: "https://github.com/fosferon/comm_bus",
      package: package(),
      docs: docs()
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
      {:yaml_elixir, "~> 2.12"},
      {:file_system, "~> 1.1"},
      {:alf, "~> 0.12"},
      {:ecto, "~> 3.13"},
      {:telemetry_metrics, "~> 1.1"},
      {:stream_data, "~> 1.2", only: :test},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      name: "comm_bus",
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/fosferon/comm_bus",
        "Changelog" => "https://github.com/fosferon/comm_bus/blob/main/CHANGELOG.md"
      },
      maintainers: ["Leonidas"],
      files: ~w(lib config .formatter.exs mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "docs/adopting_commbus.md",
        "docs/integration.md"
      ],
      groups_for_extras: [
        Guides: ~r/docs\/.*/
      ],
      groups_for_modules: [
        Core: [
          CommBus,
          CommBus.Assembler,
          CommBus.Matcher,
          CommBus.Budget,
          CommBus.Budget.Planner
        ],
        "Data Structures": [
          CommBus.Entry,
          CommBus.Message,
          CommBus.Conversation,
          CommBus.Context,
          CommBus.Protocol.Packet
        ],
        "Template System": [
          CommBus.Template,
          CommBus.Template.Engine,
          CommBus.Template.Engine.BbMustache,
          CommBus.Template.Engine.ExMustache,
          CommBus.Template.Loader,
          CommBus.Template.Validator,
          CommBus.Template.Prompt
        ],
        Prompts: [
          CommBus.Prompts,
          CommBus.Prompts.Runtime,
          CommBus.Prompts.Watcher,
          CommBus.Prompts.OverrideStore
        ],
        "Protocol & Pipeline": [
          CommBus.Protocol.Pipeline,
          CommBus.Protocol.Adapter,
          CommBus.Protocol.LlmCoreAdapter
        ],
        Storage: [
          CommBus.Storage,
          CommBus.Storage.InMemory,
          CommBus.Storage.EctoAdapter,
          CommBus.Storage.Devman,
          CommBus.Storage.Human
        ],
        Methodologies: [
          CommBus.Methodology,
          CommBus.Methodologies
        ],
        Utilities: [
          CommBus.Tokenizer,
          CommBus.Tokenizer.Simple,
          CommBus.Semantic,
          CommBus.Semantic.Adapter,
          CommBus.Semantic.Simple,
          CommBus.Telemetry
        ],
        "Mix Tasks": [
          Mix.Tasks.CommBus.Budget,
          Mix.Tasks.CommBus.CompareEngines,
          Mix.Tasks.CommBus.Entries,
          Mix.Tasks.CommBus.Simulate,
          Mix.Tasks.CommBus.SyncFixtures
        ]
      ]
    ]
  end
end
