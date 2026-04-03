defmodule Mix.Tasks.CommBus.SyncFixtures do
  use Mix.Task

  @shortdoc "Sync golden fixtures from canonical prompt roots"

  @moduledoc """
  Syncs prompt files from external project directories into test fixtures.

  ## Usage

      mix comm_bus.sync_fixtures [--clean]

  ## Configuration

  Set source directories via environment variables:

      HUMAN_PROMPTS_DIR=/path/to/human/prompts \\
      DEVMAN_PROMPTS_DIR=/path/to/devman/prompts \\
      mix comm_bus.sync_fixtures

  Or pass them as arguments:

      mix comm_bus.sync_fixtures --human /path/to/human/prompts --devman /path/to/devman/prompts

  ## Options

    * `--clean` - Remove existing fixtures before syncing
    * `--human` - Path to HuMan prompts directory
    * `--devman` - Path to DevMan prompts directory
  """

  @doc """
  Synchronizes prompt files from external project directories into the
  golden test fixture directory, optionally cleaning existing fixtures first.

  ## Parameters

    - `args` — Command-line argument list; supports `--clean`, `--human`, `--devman`.
  """
  @impl true
  def run(args) do
    {opts, _rest, _} =
      OptionParser.parse(args, switches: [clean: :boolean, human: :string, devman: :string])

    clean? = Keyword.get(opts, :clean, false)

    pairs =
      [
        {resolve_source(:human, opts), "test/fixtures/golden/human/prompts"},
        {resolve_source(:devman, opts), "test/fixtures/golden/devman/prompts"}
      ]
      |> Enum.filter(fn {src, _dest} -> src != nil end)

    if pairs == [] do
      Mix.shell().error("""
      No source directories configured. Set via environment variables:

          HUMAN_PROMPTS_DIR=/path/to/prompts DEVMAN_PROMPTS_DIR=/path/to/prompts mix comm_bus.sync_fixtures

      Or pass as arguments:

          mix comm_bus.sync_fixtures --human /path/to/prompts --devman /path/to/prompts
      """)
    else
      Enum.each(pairs, fn {src, dest} ->
        sync_dir(src, dest, clean?)
      end)
    end
  end

  defp resolve_source(:human, opts) do
    Keyword.get(opts, :human) || System.get_env("HUMAN_PROMPTS_DIR")
  end

  defp resolve_source(:devman, opts) do
    Keyword.get(opts, :devman) || System.get_env("DEVMAN_PROMPTS_DIR")
  end

  defp sync_dir(src, dest, clean?) do
    unless File.dir?(src) do
      Mix.raise("Source directory does not exist: #{src}")
    end

    if clean? do
      File.rm_rf!(dest)
    end

    File.mkdir_p!(dest)

    src
    |> Path.join("**/*.md")
    |> Path.wildcard()
    |> Enum.each(fn path ->
      rel = Path.relative_to(path, src)
      target = Path.join(dest, rel)
      File.mkdir_p!(Path.dirname(target))
      File.cp!(path, target)
    end)

    Mix.shell().info("Synced fixtures: #{src} -> #{dest}")
  end
end
