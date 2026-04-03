defmodule CommBus.Semantic do
  @moduledoc """
  Helper for retrieving the configured semantic adapter.
  """

  @default_adapter CommBus.Semantic.SimpleAdapter

  @doc """
  Returns the configured semantic similarity adapter module, checking options
  first, then application config, and falling back to `CommBus.Semantic.SimpleAdapter`.

  ## Parameters

    - `opts` — Keyword options; `:semantic_adapter` overrides the configured adapter.

  ## Returns

  The adapter module (an atom implementing `CommBus.Semantic.Adapter`).
  """
  @spec adapter(keyword()) :: module()
  def adapter(opts \\ []) do
    Keyword.get(opts, :semantic_adapter) ||
      Application.get_env(:comm_bus, :semantic_adapter, @default_adapter)
  end
end
