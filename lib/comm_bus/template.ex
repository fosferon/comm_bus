defmodule CommBus.Template do
  @moduledoc "Template rendering facade."

  alias CommBus.Template.{RenderError, RenderResult}

  @doc """
  Renders a Mustache template string with the given variable bindings using the
  configured template engine.

  ## Parameters

    - `template` — A Mustache template string.
    - `values` — A map of variable names to values.
    - `opts` — Keyword options:
      - `:engine` — Template engine module (default from app config).
      - `:strict_mode` — Whether to raise on missing variables (default: engine-specific).
      - `:types` — Variable type declarations for coercion.
      - `:partials` — Map of partial name to template body.
      - `:partials_func` — Function that resolves partial names to bodies.

  ## Returns

  `{:ok, %RenderResult{}}` on success or `{:error, %RenderError{}}` on failure.
  """
  @spec render(String.t(), map(), keyword()) ::
          {:ok, RenderResult.t()} | {:error, RenderError.t()}
  def render(template, values, opts \\ []) when is_binary(template) and is_map(values) do
    engine = Keyword.get(opts, :engine, default_engine())
    engine.render(template, values, opts)
  end

  @doc """
  Renders a prompt struct's body template with the given variables, automatically
  incorporating the prompt's declared variable types and name.

  ## Parameters

    - `prompt` — A `%CommBus.Template.Prompt{}` struct with a `:body` template.
    - `variables` — A map of variable bindings.
    - `opts` — Keyword options forwarded to `render/3`.

  ## Returns

  `{:ok, %RenderResult{}}` on success or `{:error, %RenderError{}}` on failure.
  """
  @spec render_prompt(CommBus.Template.Prompt.t(), map(), keyword()) ::
          {:ok, RenderResult.t()} | {:error, RenderError.t()}
  def render_prompt(%CommBus.Template.Prompt{} = prompt, variables, opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:types, prompt.variables)
      |> Keyword.put_new(:template_name, prompt.name || prompt.slug)

    render(prompt.body, variables, opts)
  end

  @doc """
  Renders a Mustache template and returns only the content string, discarding
  render metadata. A convenience wrapper around `render/3`.

  ## Parameters

    - `template` — A Mustache template string.
    - `values` — A map of variable bindings.
    - `opts` — Keyword options forwarded to `render/3`.

  ## Returns

  `{:ok, content_string}` on success or `{:error, %RenderError{}}` on failure.
  """
  @spec render_content(String.t(), map(), keyword()) ::
          {:ok, String.t()} | {:error, RenderError.t()}
  def render_content(template, values, opts \\ []) when is_binary(template) and is_map(values) do
    case render(template, values, opts) do
      {:ok, %RenderResult{content: content}} -> {:ok, content}
      {:error, error} -> {:error, error}
    end
  end

  defp default_engine do
    Application.get_env(:comm_bus, :template_engine, CommBus.Template.Engine.BbMustache)
  end
end
