defmodule CommBus.Template.Engine.ExMustache do
  @moduledoc "ExMustache-based template engine."

  @behaviour CommBus.Template.Engine

  alias CommBus.Template.{Preprocessor, RenderError, RenderResult}

  @max_partial_depth 10

  @doc """
  Renders a Mustache template using the ExMustache pure-Elixir library with support
  for strict mode, type coercion, partial resolution, default values, and control
  tag rewriting.

  ## Parameters

    - `template` — A Mustache template string.
    - `values` — A map of variable bindings (keys are stringified).
    - `opts` — Keyword options: `:strict_mode`, `:template_name`, `:types`,
      `:partials`, `:partials_func`.

  ## Returns

  `{:ok, %RenderResult{}}` on success or `{:error, %RenderError{}}` on failure.
  """
  @impl true
  def render(template, values, opts \\ []) when is_binary(template) and is_map(values) do
    strict = Keyword.get(opts, :strict_mode, true)
    template_name = Keyword.get(opts, :template_name)

    started_at = System.monotonic_time()
    values = Preprocessor.stringify_keys(values)
    variables_provided = Map.keys(values)

    types = Preprocessor.resolve_types(Keyword.get(opts, :types))

    with {:ok, coerced_vars} <- Preprocessor.coerce_variables(values, types, template_name) do
      {template, partials_loaded} =
        Preprocessor.resolve_partials(template, opts, 0, [], @max_partial_depth)

      {processed_body, defaults_keys} = Preprocessor.apply_defaults(template)
      processed_body = Preprocessor.rewrite_control_tags(processed_body)

      values =
        defaults_keys
        |> Enum.reduce(coerced_vars, fn key, acc -> Map.put_new(acc, key, false) end)
        |> Preprocessor.decorate_lists()

      try do
        parsed = ExMustache.parse(processed_body)
        rendered = ExMustache.render(parsed, values) |> IO.iodata_to_binary()
        variables_used = Preprocessor.extract_variables(processed_body)

        variables_defaulted =
          Enum.filter(defaults_keys, fn key -> not Map.has_key?(coerced_vars, key) end)

        render_time_ms =
          System.monotonic_time()
          |> Kernel.-(started_at)
          |> System.convert_time_unit(:native, :millisecond)

        if strict and missing_variables?(variables_used, values) do
          {:error,
           %RenderError{
             type: :render_failed,
             message: "Missing variables in template",
             template_name: template_name
           }}
        else
          {:ok,
           %RenderResult{
             content: rendered,
             variables_used: variables_used,
             variables_defaulted: variables_defaulted,
             variables_provided: variables_provided,
             partials_loaded: Enum.uniq(partials_loaded),
             render_time_ms: render_time_ms
           }}
        end
      rescue
        e in [RenderError] ->
          {:error, e}

        e ->
          {:error,
           %RenderError{
             type: :render_failed,
             message: Exception.message(e),
             template_name: template_name
           }}
      end
    end
  end

  defp missing_variables?(variables, values) do
    Enum.any?(variables, fn name -> not Map.has_key?(values, name) end)
  end
end
