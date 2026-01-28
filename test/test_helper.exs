ExUnit.start()

support_dir = Path.join(__DIR__, "support")

support_dir
|> File.ls!()
|> Enum.sort()
|> Enum.each(fn file ->
  Code.require_file(Path.join(support_dir, file))
end)
