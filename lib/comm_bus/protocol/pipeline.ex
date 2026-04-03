defmodule CommBus.Protocol.Pipeline do
  @moduledoc """
  ALF pipeline that assembles a conversation and adapts it into a protocol packet.
  """

  use ALF.DSL

  alias ALF.Manager
  alias CommBus.{Assembler, Conversation}
  alias CommBus.Protocol.{Context, Packet, Validator}
  alias CommBus.Protocol.LlmCoreAdapter

  defmodule State do
    @moduledoc """
    Internal state threaded through each ALF pipeline stage, carrying the
    protocol context, the chosen adapter module, and the accumulated result.
    """

    @enforce_keys [:context]
    defstruct context: nil, adapter: LlmCoreAdapter, result: nil
  end

  @components [
    stage(:validate_context),
    stage(:assemble_prompt),
    stage(:build_packet),
    stage(:validate_packet),
    stage(:finalize_result)
  ]

  @doc """
  Executes the ALF assembly pipeline: validates the context, assembles the
  prompt, builds a protocol packet, validates it, and returns the result.

  ## Parameters

    - `input` — A `%CommBus.Protocol.Context{}` struct, or a tuple of
      `{conversation, entries}` or `{conversation, entries, opts}`.
    - `opts` — Keyword options: `:adapter` (protocol adapter module,
      defaults to `CommBus.Protocol.LlmCoreAdapter`).

  ## Returns

  `{:ok, %CommBus.Protocol.Packet{}}` on success or `{:error, reason}` on failure.
  """
  @spec run(Context.t() | tuple(), keyword()) :: {:ok, Packet.t()} | {:error, term()}
  def run(input, opts \\ []) do
    ensure_started()

    state = %State{
      context: normalize_input(input),
      adapter: Keyword.get(opts, :adapter, LlmCoreAdapter)
    }

    Manager.call(state, __MODULE__, sync: true)
  end

  @doc """
  Pipeline stage that validates the context has a valid conversation and entry list.
  Returns the state unchanged if valid, or sets an error result if invalid.
  """
  @spec validate_context(State.t(), keyword()) :: State.t()
  def validate_context(
        %State{context: %Context{conversation: %Conversation{}, entries: entries}} = state,
        _opts
      )
      when is_list(entries) do
    state
  end

  def validate_context(%State{} = state, _opts) do
    %{state | result: {:error, :invalid_context}}
  end

  @doc """
  Pipeline stage that runs prompt assembly on the context's conversation and
  entries, attaching the assembly result to the context.
  """
  @spec assemble_prompt(State.t(), keyword()) :: State.t()
  def assemble_prompt(%State{result: {:error, _}} = state, _opts), do: state

  def assemble_prompt(%State{context: %Context{} = context} = state, _opts) do
    assembly = Assembler.assemble_prompt(context.conversation, context.entries, context.opts)
    %{state | context: Context.put_assembly(context, assembly)}
  end

  @doc """
  Pipeline stage that invokes the protocol adapter to convert the assembled
  context into a protocol packet.
  """
  @spec build_packet(State.t(), keyword()) :: State.t()
  def build_packet(%State{result: {:error, _}} = state, _opts), do: state

  def build_packet(%State{context: context, adapter: adapter} = state, _opts) do
    %{state | result: adapter.assemble(context)}
  end

  @doc """
  Pipeline stage that validates the assembled packet's structure, checking
  message format, sections, and token usage.
  """
  @spec validate_packet(State.t(), keyword()) :: State.t()
  def validate_packet(%State{result: {:ok, %Packet{} = packet}} = state, _opts) do
    case Validator.validate(packet) do
      :ok -> state
      {:error, reason} -> %{state | result: {:error, reason}}
    end
  end

  def validate_packet(%State{} = state, _opts), do: state

  @doc """
  Pipeline stage that extracts the final result from the pipeline state,
  returning either the assembled packet or an error.
  """
  @spec finalize_result(State.t(), keyword()) :: {:ok, Packet.t()} | {:error, term()}
  def finalize_result(%State{result: result}, _opts) when not is_nil(result), do: result
  def finalize_result(_state, _opts), do: {:error, :assembly_failed}

  defp normalize_input(%Context{} = context), do: context

  defp normalize_input({%Conversation{} = conversation, entries}) when is_list(entries) do
    %Context{conversation: conversation, entries: entries}
  end

  defp normalize_input({%Conversation{} = conversation, entries, opts}) when is_list(entries) do
    %Context{conversation: conversation, entries: entries, opts: opts}
  end

  defp normalize_input(_), do: raise(ArgumentError, "invalid pipeline input")

  defp ensure_started do
    unless Manager.started?(__MODULE__) do
      :ok = Manager.start(__MODULE__, sync: true)
    end
  end
end
