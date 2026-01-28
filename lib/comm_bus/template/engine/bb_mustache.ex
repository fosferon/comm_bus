defmodule CommBus.Template.Engine.BbMustache do
  @moduledoc "bbmustache-based template engine."

  @behaviour CommBus.Template.Engine

  alias CommBus.Template.{Preprocessor, RenderError, RenderResult}

  @max_partial_depth 10

  @impl true
  def render(template, values, opts \\ []) when is_binary(template) and is_map(values) do
    strict = Keyword.get(opts, :strict_mode, true)
    template_name = Keyword.get(opts, :template_name)

    started_at = System.monotonic_time()
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

      options = [
        key_type: :binary,
        raise_on_context_miss: strict
      ]

      try do
        rendered = :bbmustache.render(processed_body, values, options)
        variables_used = Preprocessor.extract_variables(processed_body)

        variables_defaulted =
          Enum.filter(defaults_keys, fn key -> not Map.has_key?(coerced_vars, key) end)

        render_time_ms =
          System.monotonic_time()
          |> Kernel.-(started_at)
          |> System.convert_time_unit(:native, :millisecond)

        {:ok,
         %RenderResult{
           content: rendered,
           variables_used: variables_used,
           variables_defaulted: variables_defaulted,
           variables_provided: variables_provided,
           partials_loaded: Enum.uniq(partials_loaded),
           render_time_ms: render_time_ms
         }}
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
end
