defmodule CommBus.Template.RenderContext do
  @type t :: %__MODULE__{
          variables: map(),
          partials: map(),
          strict_mode: boolean()
        }

  defstruct variables: %{}, partials: %{}, strict_mode: true

  @spec new(map() | keyword()) :: t()
  def new(vars_or_opts \\ %{})

  def new(vars) when is_map(vars) do
    %__MODULE__{variables: vars}
  end

  def new(opts) when is_list(opts) do
    vars = Keyword.get(opts, :variables, %{})

    %__MODULE__{
      variables: vars,
      partials: Keyword.get(opts, :partials, %{}),
      strict_mode: Keyword.get(opts, :strict_mode, true)
    }
  end
end

defmodule CommBus.Template.RenderResult do
  @type t :: %__MODULE__{
          content: String.t(),
          variables_used: [String.t()],
          variables_defaulted: [String.t()],
          variables_provided: [String.t()],
          partials_loaded: [String.t()],
          render_time_ms: non_neg_integer()
        }

  defstruct content: "",
            variables_used: [],
            variables_defaulted: [],
            variables_provided: [],
            partials_loaded: [],
            render_time_ms: 0
end

defmodule CommBus.Template.RenderError do
  defexception [:type, :message, :template_name, :variable_name]

  @type t :: %__MODULE__{
          type: atom(),
          message: String.t(),
          template_name: String.t() | nil,
          variable_name: String.t() | nil
        }

  def message(%__MODULE__{message: msg}), do: msg
end
