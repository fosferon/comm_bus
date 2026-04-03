defmodule CommBus.Prompts do
  @moduledoc """
  Prompt catalog with optional overrides and cached runtime loading.
  """

  alias CommBus.Template
  alias CommBus.Template.Loader
  alias CommBus.Template.Prompt

  @cache_key {__MODULE__, :prompts}
  @default_root Path.expand("config/comm_bus/prompts", File.cwd!())

  @doc """
  Returns the configured prompt root directory, falling back to
  `config/comm_bus/prompts` relative to the project root.

  ## Returns

  A string path to the prompt directory.
  """
  @spec default_root() :: String.t()
  def default_root do
    Application.get_env(:comm_bus, :prompt_root, @default_root)
  end

  @doc """
  Loads all prompt files from the configured root directory, caches them in
  `:persistent_term`, and returns the prompt map.

  ## Parameters

    - `opts` — Keyword options: `:root` (directory path), `:schema` (`:devman`, `:human`, `:flex`).

  ## Returns

  A map of prompt keys to `%CommBus.Template.Prompt{}` structs.

  ## Raises

  Raises if any prompt files fail validation.
  """
  @spec load_from_disk!(keyword()) :: map()
  def load_from_disk!(opts \\ []) do
    root = Keyword.get(opts, :root, default_root())
    schema = Keyword.get(opts, :schema, :flex)

    case Loader.load_prompts(root, schema: schema, root: root) do
      {:ok, prompts} ->
        map = Map.new(prompts, &{prompt_key(&1), &1})
        :persistent_term.put(@cache_key, map)
        map

      {:error, errors} ->
        raise "Failed to load prompts: #{inspect(errors)}"
    end
  end

  @doc """
  Returns all cached prompts as a list, loading from disk if not yet cached.

  ## Returns

  A list of `%CommBus.Template.Prompt{}` structs.
  """
  @spec list_prompts() :: [Prompt.t()]
  def list_prompts do
    Map.values(cache())
  end

  @doc """
  Fetches a cached prompt by its key (slug, name, or path), raising if not found.

  ## Parameters

    - `key` — The prompt identifier string.

  ## Returns

  A `%CommBus.Template.Prompt{}` struct.

  ## Raises

  Raises if no prompt matches the given key.
  """
  @spec get_prompt!(String.t()) :: Prompt.t()
  def get_prompt!(key) do
    case Map.fetch(cache(), key) do
      {:ok, prompt} -> prompt
      :error -> raise "Prompt not found: #{key}"
    end
  end

  @doc """
  Returns the prompt body for the given key, checking the override store first,
  then falling back to the cached prompt's body.

  ## Parameters

    - `key` — The prompt identifier string.
    - `opts` — Keyword options forwarded to the override store.

  ## Returns

  The prompt body as a `String.t()`.
  """
  @spec body!(String.t(), keyword()) :: String.t()
  def body!(key, opts \\ []) do
    case override_content(key, opts) do
      {:ok, content} -> content
      :error -> get_prompt!(key).body
    end
  end

  @doc """
  Renders a prompt by key with the given variables, applying any active
  override before rendering. Raises on failure.

  ## Parameters

    - `key` — The prompt identifier string.
    - `vars` — A map of template variable bindings.
    - `opts` — Keyword options forwarded to the template engine.

  ## Returns

  The rendered content as a `String.t()`.
  """
  @spec render!(String.t(), map(), keyword()) :: String.t()
  def render!(key, vars \\ %{}, opts \\ []) do
    prompt = get_prompt!(key)
    content = body!(key, opts)

    case content == prompt.body do
      true ->
        {:ok, result} = Template.render_prompt(prompt, vars, opts)
        result.content

      false ->
        {:ok, result} = Template.render(content, vars, opts)
        result.content
    end
  end

  @doc """
  Reloads all prompts from disk, refreshing the `:persistent_term` cache.

  ## Returns

  A map of prompt keys to `%CommBus.Template.Prompt{}` structs.
  """
  @spec reload!() :: map()
  def reload!, do: load_from_disk!()

  defp cache do
    case :persistent_term.get(@cache_key, :undefined) do
      :undefined ->
        load_from_disk!()
        :persistent_term.get(@cache_key)

      map ->
        map
    end
  end

  defp override_content(key, opts) do
    case override_store().get_active_override(key, opts) do
      %{content: content} when is_binary(content) -> {:ok, content}
      _ -> :error
    end
  end

  defp override_store do
    Application.get_env(:comm_bus, :prompt_override_store, CommBus.Prompts.OverrideStore.Noop)
  end

  defp prompt_key(%Prompt{} = prompt) do
    prompt.slug || prompt.name || prompt.path
  end
end
