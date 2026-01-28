defmodule CommBus.Protocol.SectionRoles do
  @moduledoc """
  Registry for mapping CommBus sections (e.g., :system, :pre_history) to downstream
  message roles understood by provider pipelines.

  Sections default to `:system` roles, but callers can register additional mappings
  (for example, mapping `:memory` sections to `:assistant`). Overrides from pipeline
  opts still take precedence, so projects can adjust behaviour per request.
  """

  @type section :: atom() | String.t()
  @type role :: atom() | String.t()
  @type mapping :: %{optional(atom()) => atom()}

  @persist_key {__MODULE__, :roles}

  @default_roles %{
    system: :system,
    pre_history: :system,
    post_history: :system
  }

  @doc "Returns the built-in section-role mapping."
  @spec default_roles() :: mapping()
  def default_roles, do: @default_roles

  @doc "Returns the currently configured section-role mapping."
  @spec get() :: mapping()
  def get do
    :persistent_term.get(@persist_key, @default_roles)
  end

  @doc "Registers or updates a mapping between a section and a downstream role."
  @spec put(section(), role()) :: :ok | {:error, term()}
  def put(section, role) do
    with {:ok, section_atom} <- normalize_section(section),
         {:ok, role_atom} <- normalize_role(role) do
      update(fn roles -> Map.put(roles, section_atom, role_atom) end)
    end
  end

  @doc "Registers multiple mappings at once."
  @spec put_all(map() | keyword()) :: :ok
  def put_all(mappings) when is_map(mappings) or is_list(mappings) do
    normalized = normalize_map(mappings)
    update(fn roles -> Map.merge(roles, normalized) end)
  end

  @doc "Removes a custom mapping for the provided section."
  @spec delete(section()) :: :ok | {:error, term()}
  def delete(section) do
    with {:ok, section_atom} <- normalize_section(section) do
      update(fn roles -> Map.delete(roles, section_atom) end)
    end
  end

  @doc "Resets all mappings back to factory defaults."
  @spec reset() :: :ok
  def reset do
    :persistent_term.put(@persist_key, @default_roles)
    :ok
  end

  @doc "Returns the resolved mapping merged with optional overrides (map/keyword)."
  @spec resolve(map() | keyword()) :: mapping()
  def resolve(overrides \\ %{}) do
    overrides = normalize_map(overrides)
    Map.merge(get(), overrides)
  end

  defp update(fun) when is_function(fun, 1) do
    new_roles = fun.(get())
    :persistent_term.put(@persist_key, new_roles)
    :ok
  end

  defp normalize_map(mappings) when is_list(mappings) do
    mappings |> Map.new() |> normalize_map()
  end

  defp normalize_map(mappings) when is_map(mappings) do
    Enum.reduce(mappings, %{}, fn {section, role}, acc ->
      case {normalize_section(section), normalize_role(role)} do
        {{:ok, section_atom}, {:ok, role_atom}} -> Map.put(acc, section_atom, role_atom)
        _ -> acc
      end
    end)
  end

  defp normalize_section(section) when is_atom(section), do: {:ok, section}

  defp normalize_section(section) when is_binary(section) do
    case String.trim(section) do
      "" -> {:error, :invalid_section}
      trimmed -> {:ok, String.to_atom(trimmed)}
    end
  end

  defp normalize_section(_), do: {:error, :invalid_section}

  defp normalize_role(role) when is_atom(role), do: {:ok, role}

  defp normalize_role(role) when is_binary(role) do
    case String.trim(role) do
      "" -> {:error, :invalid_role}
      trimmed -> {:ok, String.to_atom(trimmed)}
    end
  end

  defp normalize_role(_), do: {:error, :invalid_role}
end
