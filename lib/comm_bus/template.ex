defmodule CommBus.Template do
  @moduledoc "Template rendering facade."

  alias CommBus.Template.{RenderError, RenderResult}

  @spec render(String.t(), map(), keyword()) ::
          {:ok, RenderResult.t()} | {:error, RenderError.t()}
  def render(template, values, opts \\ []) when is_binary(template) and is_map(values) do
    engine = Keyword.get(opts, :engine, default_engine())
    engine.render(template, values, opts)
  end

  @spec render_prompt(CommBus.Template.Prompt.t(), map(), keyword()) ::
          {:ok, RenderResult.t()} | {:error, RenderError.t()}
  def render_prompt(%CommBus.Template.Prompt{} = prompt, variables, opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:types, prompt.variables)
      |> Keyword.put_new(:template_name, prompt.name || prompt.slug)

    render(prompt.body, variables, opts)
  end

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
