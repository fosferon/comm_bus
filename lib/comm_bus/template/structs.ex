defmodule CommBus.Template.RenderContext do
  @moduledoc """
  Encapsulates the rendering context passed to template engines, including
  variable bindings, partial templates, and strict-mode configuration.
  """

  @type t :: %__MODULE__{
          variables: map(),
          partials: map(),
          strict_mode: boolean()
        }

  defstruct variables: %{}, partials: %{}, strict_mode: true

  @doc """
  Creates a new render context from a variable map or a keyword list of options.

  When given a map, it is used as the variable bindings. When given a keyword
  list, recognised keys are `:variables`, `:partials`, and `:strict_mode`.

  ## Parameters

    - `vars_or_opts` — A map of template variables **or** a keyword list with
      `:variables`, `:partials`, and `:strict_mode` keys.

  ## Returns

  A `%CommBus.Template.RenderContext{}` struct.
  """
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
  @moduledoc """
  Holds the output of a successful template render, including the rendered
  content string, lists of variables that were used, defaulted, or provided,
  any partials that were loaded, and the wall-clock render time.
  """

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
  @moduledoc """
  Exception raised or returned when a template render fails. Carries the
  failure `:type` (e.g. `:render_failed`, `:type_coercion_failed`,
  `:max_depth_exceeded`), a human-readable `:message`, and optional
  `:template_name` and `:variable_name` for diagnostics.
  """

  defexception [:type, :message, :template_name, :variable_name]

  @type t :: %__MODULE__{
          type: atom(),
          message: String.t(),
          template_name: String.t() | nil,
          variable_name: String.t() | nil
        }

  @doc """
  Returns the human-readable error message string.

  ## Parameters

    - `error` — A `%CommBus.Template.RenderError{}` struct.

  ## Returns

  The error message as a `String.t()`.
  """
  @spec message(t()) :: String.t()
  def message(%__MODULE__{message: msg}), do: msg
end
