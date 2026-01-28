defmodule CommBus.Entry do
  @moduledoc "Injectable context entry."

  @type mode :: :constant | :triggered
  @type match_mode :: :any | :all
  @type match_strategy :: :exact | :fuzzy | :semantic
  @type section :: :system | :pre_history | :history | :post_history

  @type t :: %__MODULE__{
          id: term(),
          content: String.t(),
          keywords: [String.t()],
          priority: integer(),
          weight: integer(),
          token_count: non_neg_integer() | nil,
          enabled: boolean(),
          mode: mode(),
          match_mode: match_mode(),
          match_strategy: match_strategy(),
          section: section(),
          metadata: map(),
          exclude_keywords: [String.t()],
          scan_depth: pos_integer() | nil,
          cooldown_turns: non_neg_integer() | nil,
          match_threshold: number() | nil,
          fuzzy_threshold: number() | nil,
          semantic_hints: [String.t()],
          semantic_threshold: number() | nil
        }

  defstruct id: nil,
            content: "",
            keywords: [],
            priority: 0,
            weight: 0,
            token_count: nil,
            enabled: true,
            mode: :triggered,
            match_mode: :any,
            match_strategy: :exact,
            section: :pre_history,
            metadata: %{},
            exclude_keywords: [],
            scan_depth: nil,
            cooldown_turns: nil,
            match_threshold: nil,
            fuzzy_threshold: 0.85,
            semantic_hints: [],
            semantic_threshold: 0.75
end
