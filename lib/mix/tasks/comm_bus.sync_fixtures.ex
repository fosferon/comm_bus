defmodule Mix.Tasks.CommBus.SyncFixtures do
  use Mix.Task

  @shortdoc "Sync golden fixtures from canonical prompt roots"

  @impl true
  def run(args) do
    {opts, _rest, _} = OptionParser.parse(args, switches: [clean: :boolean])
    clean? = Keyword.get(opts, :clean, false)

    pairs = [
      {"/Users/leonidas/Sites/HuMan/config/hu_man/prompts", "test/fixtures/golden/human/prompts"},
      {"/Users/leonidas/Sites/DevMan/dev_man/config/devman/prompts",
       "test/fixtures/golden/devman/prompts"}
    ]

    Enum.each(pairs, fn {src, dest} ->
      sync_dir(src, dest, clean?)
    end)
  end

  defp sync_dir(src, dest, clean?) do
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
