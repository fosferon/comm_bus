defmodule CommBus.Template.Loader do
  @moduledoc "Prompt template loader with YAML frontmatter."

  alias CommBus.Template.{Prompt, ValidationError, Validator}

  @doc """
  Reads a prompt file from disk, parses its YAML frontmatter, validates the
  schema, and returns a `%Prompt{}` struct.

  ## Parameters

    - `path` — Absolute or relative file path to a Markdown prompt file.
    - `opts` — Keyword options: `:schema` (`:devman`, `:human`, `:flex`),
      `:root` (prompt root directory for slug derivation).

  ## Returns

  `{:ok, %Prompt{}}` on success or `{:error, [%ValidationError{}]}` on failure.
  """
  @spec load_prompt_file(String.t(), keyword()) ::
          {:ok, Prompt.t()} | {:error, [ValidationError.t()]}
  def load_prompt_file(path, opts \\ []) when is_binary(path) do
    case File.read(path) do
      {:ok, content} ->
        load_prompt_string(content, path, opts)

      {:error, err} ->
        {:error,
         [
           %ValidationError{
             path: path,
             field: nil,
             message: "Failed to read prompt file: #{inspect(err)}"
           }
         ]}
    end
  end

  @doc """
  Parses a prompt from a raw string containing YAML frontmatter delimited by
  `---`, validates the schema, and returns a `%Prompt{}` struct.

  ## Parameters

    - `content` — The full prompt string including YAML frontmatter.
    - `path` — Optional file path for error reporting and slug derivation.
    - `opts` — Keyword options: `:schema`, `:root`.

  ## Returns

  `{:ok, %Prompt{}}` on success or `{:error, [%ValidationError{}]}` on failure.
  """
  @spec load_prompt_string(String.t(), String.t() | nil, keyword()) ::
          {:ok, Prompt.t()} | {:error, [ValidationError.t()]}
  def load_prompt_string(content, path \\ nil, opts \\ []) when is_binary(content) do
    case parse_frontmatter(content, path) do
      {:ok, frontmatter, body} ->
        case Validator.validate_prompt(frontmatter, body, path, opts) do
          {:ok, :prompt} ->
            {:ok, to_prompt_struct(frontmatter, body, path, opts)}

          {:error, errs} ->
            {:error, errs}
        end

      {:error, errs} ->
        {:error, errs}
    end
  end

  @doc """
  Splits a prompt string on `---` delimiters and parses the YAML frontmatter
  into a map.

  ## Parameters

    - `content` — The full prompt string.
    - `path` — Optional file path for error reporting.

  ## Returns

  `{:ok, frontmatter_map, body_string}` on success or
  `{:error, [%ValidationError{}]}` on failure.
  """
  @spec parse_frontmatter(String.t(), String.t() | nil) ::
          {:ok, map(), String.t()} | {:error, [ValidationError.t()]}
  def parse_frontmatter(content, path \\ nil) when is_binary(content) do
    case String.split(content, ~r/^---\n/m, parts: 3) do
      ["", yaml, body] ->
        case YamlElixir.read_from_string(yaml) do
          {:ok, map} ->
            {:ok, map, String.trim(body)}

          {:error, %YamlElixir.ParsingError{} = err} ->
            {:error,
             [
               %ValidationError{
                 path: path,
                 field: "frontmatter",
                 line: err.line,
                 message: "Invalid YAML frontmatter: #{err.message}"
               }
             ]}

          {:error, err} ->
            {:error,
             [
               %ValidationError{
                 path: path,
                 field: "frontmatter",
                 message: "Invalid YAML frontmatter: #{inspect(err)}"
               }
             ]}
        end

      _ ->
        {:error,
         [
           %ValidationError{
             path: path,
             field: "frontmatter",
             message: "Missing YAML frontmatter delimiters (---)"
           }
         ]}
    end
  end

  @doc """
  Recursively loads all `.md` prompt files under the given directory, returning
  a list of validated `%Prompt{}` structs.

  ## Parameters

    - `root` — The root directory to scan for prompt files.
    - `opts` — Keyword options: `:schema`, `:root`.

  ## Returns

  `{:ok, [%Prompt{}]}` if all files pass validation, or
  `{:error, [%ValidationError{}]}` collecting errors from all invalid files.
  """
  @spec load_prompts(String.t(), keyword()) ::
          {:ok, [Prompt.t()]} | {:error, [ValidationError.t()]}
  def load_prompts(root, opts \\ []) when is_binary(root) do
    root = Path.expand(root)

    paths =
      root
      |> Path.join("**/*.md")
      |> Path.wildcard()

    {prompts, errors} =
      Enum.reduce(paths, {[], []}, fn path, {prompts, errors} ->
        case load_prompt_file(path, Keyword.put_new(opts, :root, root)) do
          {:ok, prompt} -> {[prompt | prompts], errors}
          {:error, errs} -> {prompts, errors ++ errs}
        end
      end)

    if errors == [], do: {:ok, Enum.reverse(prompts)}, else: {:error, errors}
  end

  defp to_prompt_struct(frontmatter, body, path, opts) do
    schema = Keyword.get(opts, :schema, :devman)
    root = Keyword.get(opts, :root)
    slug = Map.get(frontmatter, "slug") || derive_slug(path, root, schema)

    %Prompt{
      name: Map.get(frontmatter, "name"),
      slug: slug,
      description: Map.get(frontmatter, "description"),
      variables: Map.get(frontmatter, "variables", []),
      body: body,
      path: path,
      metadata: Map.drop(frontmatter, ["name", "slug", "description", "variables"])
    }
  end

  defp derive_slug(_path, _root, :devman), do: nil

  defp derive_slug(path, root, :human) when is_binary(path) and is_binary(root) do
    relative = Path.relative_to(path, root)

    relative
    |> Path.rootname()
    |> String.replace("\\", "/")
    |> String.replace(~r/\s+/, "_")
  end

  defp derive_slug(_path, _root, _schema), do: nil
end
