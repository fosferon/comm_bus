defmodule CommBus.Semantic do
  @moduledoc """
  Helper for retrieving the configured semantic adapter.
  """

  @default_adapter CommBus.Semantic.SimpleAdapter

  @spec adapter(keyword()) :: module()
  def adapter(opts \\ []) do
    Keyword.get(opts, :semantic_adapter) ||
      Application.get_env(:comm_bus, :semantic_adapter, @default_adapter)
  end
end
