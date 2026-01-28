defmodule CommBus.Methodology do
  @moduledoc "Structured methodology definition containing curated CommBus entries."

  alias CommBus.Entry

  @enforce_keys [:slug, :name, :description, :entries]
  defstruct slug: nil,
            name: nil,
            description: nil,
            tags: [],
            entries: []

  @type t :: %__MODULE__{
          slug: String.t(),
          name: String.t(),
          description: String.t(),
          tags: [String.t()],
          entries: [Entry.t()]
        }
end
