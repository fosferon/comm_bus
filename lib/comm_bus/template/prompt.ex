defmodule CommBus.Template.Prompt do
  @moduledoc "Prompt template definition."

  @type t :: %__MODULE__{
          name: String.t() | nil,
          slug: String.t() | nil,
          description: String.t() | nil,
          variables: [String.t() | map()],
          body: String.t(),
          path: String.t() | nil,
          metadata: map()
        }

  @enforce_keys [:body]
  defstruct [:name, :slug, :description, :body, :path, variables: [], metadata: %{}]
end
