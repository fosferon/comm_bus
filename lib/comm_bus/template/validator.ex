defmodule CommBus.Template.Validator do
  @moduledoc """
  Validates prompt frontmatter and variable consistency.
  """

  alias CommBus.Template.{Prompt, RenderError, RenderResult, ValidationError, ValidationResult}

  @type error_list :: [ValidationError.t()]

  @spec validate_prompt(map(), String.t(), String.t() | nil, keyword()) ::
          {:ok, :prompt} | {:error, error_list()}
  def validate_prompt(frontmatter, body, path \\ nil, opts \\ [])
      when is_map(frontmatter) and is_binary(body) do
    schema = Keyword.get(opts, :schema, :devman)
    require_fields = required_fields(schema)
    validate_vars? = Keyword.get(opts, :validate_variables, schema == :devman)

    errors =
      []
      |> require_keys(frontmatter, require_fields, path)
      |> validate_variable_decls(frontmatter["variables"], path)

    errors =
      if validate_vars? do
        validate_prompt_variable_consistency(errors, frontmatter["variables"], body, path)
      else
        errors
      end

    if errors == [], do: {:ok, :prompt}, else: {:error, errors}
  end

  @spec validate_prompt_struct(Prompt.t(), map(), keyword()) ::
          {:ok, ValidationResult.t()} | {:error, RenderError.t()}
  def validate_prompt_struct(%Prompt{} = prompt, variables \\ %{}, opts \\ []) do
    opts = Keyword.put(opts, :strict_mode, true)

    case CommBus.Template.render_prompt(prompt, variables, opts) do
      {:ok, %RenderResult{}} ->
        {:ok,
         %ValidationResult{
           valid: true,
           variables_required: declared_vars(prompt.variables),
           partials_required: extract_template_partials(prompt.body)
         }}

      {:error, %RenderError{} = err} ->
        {:error, err}
    end
  end

  defp require_keys(errors, map, keys, path) do
    Enum.reduce(keys, errors, fn key, acc ->
      if Map.has_key?(map, key) do
        acc
      else
        [%ValidationError{path: path, field: key, message: "Missing required key"} | acc]
      end
    end)
  end

  defp validate_variable_decls(errors, variables, path) when is_list(variables) do
    Enum.reduce(variables, errors, fn
      %{"name" => name} = decl, acc ->
        validate_variable_decl(acc, name, decl["type"], path)

      name, acc when is_binary(name) ->
        validate_variable_decl(acc, name, nil, path)

      _other, acc ->
        [
          %ValidationError{
            path: path,
            field: "variables",
            message: "Invalid variable declaration"
          }
          | acc
        ]
    end)
  end

  defp validate_variable_decls(errors, nil, _path), do: errors

  defp validate_variable_decls(errors, _variables, path) do
    [
      %ValidationError{path: path, field: "variables", message: "variables must be a list"}
      | errors
    ]
  end

  defp validate_variable_decl(errors, name, type, path) do
    valid_name? = Regex.match?(~r/^[a-zA-Z0-9_-]+$/, name)
    valid_type? = is_nil(type) or type in ["string", "integer", "boolean", "list"]

    errors =
      if valid_name? do
        errors
      else
        [
          %ValidationError{
            path: path,
            field: "variables.name",
            message: "Invalid variable name: #{name}"
          }
          | errors
        ]
      end

    if valid_type? do
      errors
    else
      [
        %ValidationError{
          path: path,
          field: "variables.type",
          message: "Invalid type for #{name}: #{type}"
        }
        | errors
      ]
    end
  end

  defp validate_prompt_variable_consistency(errors, variables_decl, body, path) do
    declared =
      variables_decl
      |> List.wrap()
      |> Enum.map(fn
        %{"name" => name} -> name
        name when is_binary(name) -> name
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    used =
      body
      |> extract_template_variables()
      |> MapSet.new()

    used = MapSet.difference(used, MapSet.new(["this", "@index"]))

    undeclared = MapSet.difference(used, declared) |> MapSet.to_list()
    unused = MapSet.difference(declared, used) |> MapSet.to_list()

    errors =
      Enum.reduce(undeclared, errors, fn name, acc ->
        [
          %ValidationError{
            path: path,
            field: "variables",
            message: "Variable used but not declared: #{name}"
          }
          | acc
        ]
      end)

    Enum.reduce(unused, errors, fn name, acc ->
      [
        %ValidationError{
          path: path,
          field: "variables",
          message: "Variable declared but not used: #{name}"
        }
        | acc
      ]
    end)
  end

  defp extract_template_variables(body) do
    regex = ~r/\{\{\s*([#^\/>]?)\s*([a-zA-Z0-9_@-]+)(?:\s*\|[^}]*)?\s*\}\}/

    Regex.scan(regex, body)
    |> Enum.map(fn
      [_, ">", _partial] -> nil
      [_, "#", "each"] -> nil
      [_, _sigil, name] -> name
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_template_partials(body) do
    regex = ~r/\{\{\s*>\s*([a-zA-Z0-9_@:\/\-]+)\s*\}\}/

    Regex.scan(regex, body)
    |> Enum.map(fn [_, name] -> name end)
    |> Enum.uniq()
  end

  defp declared_vars(decls) when is_list(decls) do
    Enum.map(decls, fn
      %{"name" => name} -> name
      name when is_binary(name) -> name
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp declared_vars(_), do: []

  defp required_fields(:devman), do: ["name", "description", "variables"]
  defp required_fields(:human), do: []
  defp required_fields(:flex), do: []
  defp required_fields(_), do: ["name", "description", "variables"]
end
