defmodule CommBus.Semantic.Adapter do
  @moduledoc """
  Behaviour for semantic similarity adapters used by CommBus.Matcher.
  Implementations should return a similarity score between 0.0 and 1.0.
  """

  @callback similarity(CommBus.Entry.t(), String.t(), String.t(), keyword()) :: number()
end
