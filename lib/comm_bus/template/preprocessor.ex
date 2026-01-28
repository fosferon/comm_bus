defmodule CommBus.Template.Preprocessor do
  @moduledoc false

  alias CommBus.Template.RenderError

  def resolve_types(nil), do: %{}
  def resolve_types(types) when is_map(types), do: types
  def resolve_types(types) when is_list(types), do: variable_types(types)

  def coerce_variables(vars, types, template_name) when is_map(vars) do
    Enum.reduce_while(types, {:ok, vars}, fn {name, type}, {:ok, acc} ->
      case Map.fetch(acc, name) do
        :error ->
          {:cont, {:ok, acc}}

        {:ok, value} ->
          case coerce_value(value, type) do
            {:ok, coerced} ->
              {:cont, {:ok, Map.put(acc, name, coerced)}}

            {:error, reason} ->
              {:halt,
               {:error,
                %RenderError{
                  type: :type_coercion_failed,
                  message: "Type coercion failed for #{name}: #{reason}",
                  template_name: template_name,
                  variable_name: name
                }}}
          end
      end
    end)
  end

  def apply_defaults(template) do
    regex = ~r/\{\{\s*([a-zA-Z0-9_-]+)\s*\|\s*default:\s*"([^"]+)"\s*\}\}/

    keys = Regex.scan(regex, template) |> Enum.map(fn [_, key, _] -> key end) |> Enum.uniq()

    processed =
      Regex.replace(regex, template, fn _, var, default ->
        "{{##{var}}}{{#{var}}}{{/#{var}}}{{^#{var}}}#{default}{{/#{var}}}"
      end)

    {processed, keys}
  end

  def rewrite_control_tags(template) do
    tokens = Regex.split(~r/(\{\{[^}]+\}\})/, template, include_captures: true, trim: false)
    {out, _stack} = Enum.reduce(tokens, {[], []}, &rewrite_token/2)
    Enum.reverse(out) |> IO.iodata_to_binary()
  end

  def decorate_lists(vars) do
    Enum.reduce(vars, vars, fn
      {k, v}, acc when is_list(v) ->
        items =
          v
          |> Enum.with_index()
          |> Enum.map(fn {item, idx} ->
            base =
              cond do
                is_map(item) -> item
                true -> %{"this" => item}
              end

            Map.merge(base, %{"@index" => idx, "this" => Map.get(base, "this", item)})
          end)

        Map.put(acc, k, items)

      _other, acc ->
        acc
    end)
  end

  def resolve_partials(template, opts, depth, loaded, max_depth) do
    if depth >= max_depth do
      raise %RenderError{type: :max_depth_exceeded, message: "Max partial depth exceeded"}
    end

    resolver = partial_resolver(opts)
    raise_on_partial_miss = Keyword.get(opts, :raise_on_partial_miss, false)

    regex = ~r/\{\{\s*>\s*([a-zA-Z0-9_@:\/\-]+)\s*\}\}/

    {result, loaded} =
      Regex.scan(regex, template)
      |> Enum.reduce({template, loaded}, fn [match, name], {acc, seen} ->
        {replacement, nested_loaded} =
          case resolver.(name) do
            nil when raise_on_partial_miss ->
              raise %RenderError{type: :partial_not_found, message: "Partial not found: #{name}"}

            nil ->
              {"", seen}

            body ->
              {rendered, child_loaded} = resolve_partials(body, opts, depth + 1, seen, max_depth)

              {
                rendered |> apply_defaults() |> elem(0) |> rewrite_control_tags(),
                child_loaded
              }
          end

        {
          String.replace(acc, match, replacement, global: false),
          [normalize_partial_name(name) | nested_loaded]
        }
      end)

    {result, loaded}
  end

  def extract_variables(template) do
    regex = ~r/\{\{\s*([#^\/>]?)\s*([a-zA-Z0-9_@-]+)(?:\s*\|[^}]*)?\s*\}\}/

    Regex.scan(regex, template)
    |> Enum.map(fn
      [_, ">", _partial] -> nil
      [_, "#", _section] -> nil
      [_, "^", _section] -> nil
      [_, "/", _end] -> nil
      [_, _sigil, name] -> name
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  def stringify_keys(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} -> {to_string(k), stringify_value(v)} end)
    |> Map.new()
  end

  defp stringify_value(value) when is_map(value), do: stringify_keys(value)
  defp stringify_value(value) when is_list(value), do: Enum.map(value, &stringify_value/1)
  defp stringify_value(value), do: value

  defp partial_resolver(opts) do
    case Keyword.get(opts, :partials_func) do
      func when is_function(func, 1) ->
        fn name -> func.(normalize_partial_name(name)) end

      _ ->
        partials = Keyword.get(opts, :partials, %{})

        fn name ->
          key = normalize_partial_name(name)
          Map.get(partials, key) || Map.get(partials, to_existing_atom(key))
        end
    end
  end

  defp normalize_partial_name(name) when is_binary(name), do: String.trim(name)

  defp normalize_partial_name(name) when is_list(name),
    do: name |> List.to_string() |> String.trim()

  defp normalize_partial_name(name), do: name |> to_string() |> String.trim()

  defp to_existing_atom(key) when is_binary(key) do
    try do
      String.to_existing_atom(key)
    rescue
      ArgumentError -> nil
    end
  end

  defp to_existing_atom(_), do: nil

  defp variable_types(decls) when is_list(decls) do
    Enum.reduce(decls, %{}, fn
      %{"name" => name, "type" => type}, acc when is_binary(name) -> Map.put(acc, name, type)
      %{"name" => name}, acc when is_binary(name) -> Map.put(acc, name, "string")
      name, acc when is_binary(name) -> Map.put(acc, name, "string")
      _other, acc -> acc
    end)
  end

  defp variable_types(_), do: %{}

  defp coerce_value(value, "string"), do: {:ok, value |> to_string()}
  defp coerce_value(value, "integer") when is_integer(value), do: {:ok, value}

  defp coerce_value(value, "integer") when is_binary(value) do
    case Integer.parse(value) do
      {i, ""} -> {:ok, i}
      _ -> {:error, "not an integer"}
    end
  end

  defp coerce_value(value, "boolean") when is_boolean(value), do: {:ok, value}

  defp coerce_value(value, "boolean") when is_binary(value) do
    case String.downcase(String.trim(value)) do
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      _ -> {:error, "not a boolean"}
    end
  end

  defp coerce_value(value, "list") when is_list(value), do: {:ok, value}

  defp coerce_value(value, "list") when is_binary(value) do
    {:ok, String.split(value, ",") |> Enum.map(&String.trim/1)}
  end

  defp coerce_value(value, _type), do: {:ok, value}

  defp rewrite_token(token, {out, stack}) do
    cond do
      Regex.match?(~r/^\{\{\s*#if\s+/, token) ->
        [_, var] = Regex.run(~r/^\{\{\s*#if\s+([a-zA-Z0-9_-]+)\s*\}\}$/, token)
        {[["{{#", var, "}}"] | out], [{:if, var} | stack]}

      token == "{{/if}}" ->
        case stack do
          [{:if, var} | rest] -> {[["{{/", var, "}}"] | out], rest}
          _ -> {[token | out], stack}
        end

      Regex.match?(~r/^\{\{\s*#unless\s+/, token) ->
        [_, var] = Regex.run(~r/^\{\{\s*#unless\s+([a-zA-Z0-9_-]+)\s*\}\}$/, token)
        {[["{{^", var, "}}"] | out], [{:unless, var} | stack]}

      token == "{{/unless}}" ->
        case stack do
          [{:unless, var} | rest] -> {[["{{/", var, "}}"] | out], rest}
          _ -> {[token | out], stack}
        end

      Regex.match?(~r/^\{\{\s*#each\s+/, token) ->
        [_, var] = Regex.run(~r/^\{\{\s*#each\s+([a-zA-Z0-9_-]+)\s*\}\}$/, token)
        {[["{{#", var, "}}"] | out], [{:each, var} | stack]}

      token == "{{/each}}" ->
        case stack do
          [{:each, var} | rest] -> {[["{{/", var, "}}"] | out], rest}
          _ -> {[token | out], stack}
        end

      true ->
        {[token | out], stack}
    end
  end
end
