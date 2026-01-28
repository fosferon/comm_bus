defmodule CommBus.Protocol.Adapter do
  @moduledoc """
  Behaviour for translating CommBus assemblies into downstream packets.
  """

  alias CommBus.Protocol.{Context, Packet}

  @callback assemble(Context.t()) :: {:ok, Packet.t()} | {:error, term()}
end
