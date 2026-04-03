defmodule CommBus.Prompts.OverrideStore do
  @moduledoc "Prompt override store behavior."

  @callback get_active_override(String.t(), keyword()) :: map() | nil
  @callback create_override(map()) :: {:ok, map()} | {:error, term()}
end

defmodule CommBus.Prompts.OverrideStore.Noop do
  @moduledoc false
  @behaviour CommBus.Prompts.OverrideStore

  @doc "Always returns `nil` — no overrides are stored in the no-op implementation."
  @impl true
  def get_active_override(_slug, _opts), do: nil

  @doc "Always returns `{:error, :unsupported}` — the no-op store does not persist overrides."
  @impl true
  def create_override(_attrs), do: {:error, :unsupported}
end
