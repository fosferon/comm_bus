defmodule CommBus.Axis do
  @moduledoc """
  Generic per-entry classification axis registry.

  An *axis* is a named per-entry dimension with a declared value domain and a
  default. Axis **values are carried in the existing `CommBus.Entry.metadata/0`
  bag** — this module only owns the registry and the resolution/validation logic.
  comm_bus ships the *mechanism*; consuming applications declare the
  vocabularies (axes) they need.

  ## What this is

  Any consumer that needs to classify entries along a known dimension (for
  example, distinguishing content the agent must keep to itself from content the
  agent is instructed to surface) can declare that dimension as an axis and tag
  entries via `metadata`. Resolution then reads the declared value or falls back
  to the axis default, validating against the declared domain. The dimension name
  and its value domain are entirely the consumer's choice; comm_bus attaches no
  semantics to either.

  ## What this is not

  This module knows nothing about *what* an axis means. There is no security,
  confidentiality, sensitivity, or assurance concept here — only "a declared
  per-entry dimension with a value domain and a default." Consumers interpret
  resolved values; comm_bus never does.

  ## Registry lifecycle

  The registry is `persistent_term`-backed (mirroring
  `CommBus.Protocol.SectionRoles`). Declarations persist for the VM lifetime
  until deleted or reset. Tests should call `reset/0` in setup to guarantee
  isolation, since `persistent_term` is global.

  ## Example

      # A consumer declares two entirely independent axes. The vocabularies are
      # the consumer's; comm_bus only stores and resolves them.
      CommBus.Axis.declare(:visibility, values: [:internal, :disclosed], default: :internal)
      CommBus.Axis.declare(:feasibility, values: [:proven, :speculative], default: :speculative)

      # Values are read from entry metadata (string keys/values from yml are
      # normalized to the declared atom domain).
      entry = %CommBus.Entry{metadata: %{"visibility" => "disclosed"}}

      {:ok, :disclosed}   = CommBus.Axis.get(entry, :visibility)
      {:ok, :speculative} = CommBus.Axis.get(entry, :feasibility)   # default fallback
      {:ok, :internal}    = CommBus.Axis.get(%CommBus.Entry{}, :visibility)

      CommBus.Axis.declared()        #=> [:visibility, :feasibility]
      CommBus.Axis.spec(:visibility) #=> %{values: [:internal, :disclosed], default: :internal}
  """

  alias CommBus.Entry

  @type axis :: atom() | String.t()
  @type value :: atom() | String.t()
  @type spec :: %{values: [atom()], default: atom()}

  @persist_key {__MODULE__, :axes}

  @empty %{}

  # ---------------------------------------------------------------------------
  # Registry declarations
  # ---------------------------------------------------------------------------

  @doc """
  Declares an axis with a value domain and a default.

  Idempotent: re-declaring an axis overwrites its previous spec. The `default`
  must be a member of `values`. Both `values` entries and `default` may be given
  as atoms or strings; they are normalized to atoms.

  ## Options

    * `:values` - required, list of atoms/strings forming the value domain.
    * `:default` - required, the fallback value; must be a member of `:values`.

  ## Examples

      iex> CommBus.Axis.reset()
      iex> CommBus.Axis.declare(:visibility, values: [:internal, :disclosed], default: :internal)
      :ok
      iex> CommBus.Axis.declared()
      [:visibility]

  """
  @spec declare(axis(), keyword()) :: :ok | {:error, term()}
  def declare(axis, opts) when is_list(opts) do
    with {:ok, axis_atom} <- normalize_axis(axis),
         {:ok, values} <- take_values(opts),
         {:ok, default} <- take_default(opts),
         {:ok, values_atoms} <- to_atom_list(values, :values),
         {:ok, default_atom} <- normalize_value(default),
         :ok <- validate_default!(default_atom, values_atoms, axis_atom) do
      spec = %{values: values_atoms, default: default_atom}
      update(fn axes -> Map.put(axes, axis_atom, spec) end)
    end
  end

  @doc """
  Removes an axis declaration.

  Removing an axis does not touch any entry's `metadata`; it only drops the
  registry entry so subsequent `get/2` calls for that axis return
  `{:error, {:unknown_axis, axis}}`.
  """
  @spec delete(axis()) :: :ok | {:error, term()}
  def delete(axis) do
    with {:ok, axis_atom} <- normalize_axis(axis) do
      update(fn axes -> Map.delete(axes, axis_atom) end)
    end
  end

  @doc """
  Resets the registry to empty (no axes declared).

  Use in test setup to guarantee isolation, since the backing `persistent_term`
  store is shared VM-wide.
  """
  @spec reset() :: :ok
  def reset do
    :persistent_term.put(@persist_key, @empty)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Introspection
  # ---------------------------------------------------------------------------

  @doc """
  Returns the names of all declared axes, in declaration order.
  """
  @spec declared() :: [atom()]
  def declared do
    @persist_key
    |> :persistent_term.get(@empty)
    |> Map.keys()
    |> Enum.sort()
  end

  @doc """
  Returns the declared spec for an axis.

  Returns `{:error, {:unknown_axis, axis}}` if the axis has not been declared.
  """
  @spec spec(axis()) :: {:ok, spec()} | {:error, term()}
  def spec(axis) do
    with {:ok, axis_atom} <- normalize_axis(axis) do
      case registry_get(axis_atom) do
        nil -> {:error, {:unknown_axis, axis_atom}}
        spec -> {:ok, spec}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Resolution
  # ---------------------------------------------------------------------------

  @doc """
  Resolves the value of an axis for a given entry.

  Resolution reads `entry.metadata[axis]`, accepting either atom or string keys
  (yml-loaded metadata uses string keys) and normalizing string values to atoms.
  The resolved value is validated against the axis's declared domain.

  ## Returns

    * `{:ok, value}` - the declared value for the entry, or the axis default when
      the entry's metadata carries no value for this axis.
    * `{:error, {:unknown_axis, axis}}` - the axis has not been declared.
    * `{:error, {:invalid_value, axis, raw}}` - the entry carries a value that is
      not a member of the axis's declared domain. Illegal stored values surface
      as an error rather than being silently coerced.

  ## Examples

      iex> CommBus.Axis.reset()
      iex> CommBus.Axis.declare(:visibility, values: [:internal, :disclosed], default: :internal)
      iex> entry = %CommBus.Entry{metadata: %{"visibility" => "disclosed"}}
      iex> CommBus.Axis.get(entry, :visibility)
      {:ok, :disclosed}
      iex> CommBus.Axis.get(%CommBus.Entry{}, :visibility)
      {:ok, :internal}

  """
  @spec get(Entry.t(), axis()) :: {:ok, atom()} | {:error, term()}
  def get(%Entry{metadata: metadata}, axis) do
    with {:ok, axis_atom} <- normalize_axis(axis),
         {:ok, %{values: values, default: default}} <- spec(axis_atom) do
      case read_metadata(metadata, axis_atom) do
        :undefined ->
          {:ok, default}

        {:value, raw} ->
          with {:ok, value_atom} <- normalize_value(raw),
               :ok <- validate_membership!(value_atom, values) do
            {:ok, value_atom}
          else
            _ -> {:error, {:invalid_value, axis_atom, raw}}
          end
      end
    end
  end

  @doc """
  Resolves the value of an axis for a given entry, raising on error.

  Like `get/2` but returns the bare value on success and raises
  `ArgumentError` on unknown axis or illegal value. Useful for call sites that
  have already validated their inputs and prefer the ergonomic form.
  """
  @spec get!(Entry.t(), axis()) :: atom()
  def get!(entry, axis) do
    case get(entry, axis) do
      {:ok, value} -> value
      {:error, reason} -> raise ArgumentError, "CommBus.Axis #{inspect(axis)}: #{inspect(reason)}"
    end
  end

  # ---------------------------------------------------------------------------
  # Internal: registry plumbing
  # ---------------------------------------------------------------------------

  defp registry_get(axis_atom) do
    :persistent_term.get(@persist_key, @empty) |> Map.get(axis_atom)
  end

  defp update(fun) when is_function(fun, 1) do
    new_axes = fun.(:persistent_term.get(@persist_key, @empty))
    :persistent_term.put(@persist_key, new_axes)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Internal: option extraction & validation
  # ---------------------------------------------------------------------------

  defp take_values(opts) do
    case Keyword.get(opts, :values) do
      nil -> {:error, :missing_values}
      [_ | _] = values -> {:ok, values}
      [] -> {:error, :empty_values}
      _ -> {:error, :invalid_values}
    end
  end

  defp take_default(opts) do
    case Keyword.fetch(opts, :default) do
      {:ok, default} -> {:ok, default}
      :error -> {:error, :missing_default}
    end
  end

  defp validate_default!(default_atom, values_atoms, _axis_atom) do
    if default_atom in values_atoms do
      :ok
    else
      {:error, {:default_not_in_values, default_atom}}
    end
  end

  defp validate_membership!(value_atom, values_atoms) do
    if value_atom in values_atoms, do: :ok, else: :error
  end

  # ---------------------------------------------------------------------------
  # Internal: normalization (atoms <-> strings), per SectionRoles idiom
  # ---------------------------------------------------------------------------

  defp normalize_axis(axis) when is_atom(axis), do: {:ok, axis}

  defp normalize_axis(axis) when is_binary(axis) do
    case String.trim(axis) do
      "" -> {:error, :invalid_axis}
      trimmed -> {:ok, String.to_atom(trimmed)}
    end
  end

  defp normalize_axis(_), do: {:error, :invalid_axis}

  defp normalize_value(value) when is_atom(value), do: {:ok, value}

  defp normalize_value(value) when is_binary(value) do
    case String.trim(value) do
      "" -> {:error, :invalid_value}
      trimmed -> {:ok, String.to_atom(trimmed)}
    end
  end

  defp normalize_value(_), do: {:error, :invalid_value}

  defp to_atom_list(values, _label) do
    Enum.reduce_while(values, {:ok, []}, fn item, {:ok, acc} ->
      case normalize_value(item) do
        {:ok, atom} -> {:cont, {:ok, [atom | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      error -> error
    end
  end

  # Read a value from metadata under either the atom or string form of the axis
  # key, preferring the atom form. Returns {:value, raw} | :undefined.
  defp read_metadata(metadata, axis_atom) do
    cond do
      is_map_key(metadata, axis_atom) ->
        {:value, Map.fetch!(metadata, axis_atom)}

      is_map_key(metadata, Atom.to_string(axis_atom)) ->
        {:value, Map.fetch!(metadata, Atom.to_string(axis_atom))}

      true ->
        :undefined
    end
  end
end
