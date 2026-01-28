defmodule CommBus.Protocol.ValidatorTest do
  use ExUnit.Case, async: true

  alias CommBus.Protocol.{Packet, Validator}

  test "valid packet passes validation" do
    packet =
      %Packet{
        messages: [
          %{role: :system, content: "Rules", metadata: %{}},
          %{role: :user, content: "Hello", metadata: %{section: :history}}
        ],
        sections: %{system: [%{id: 1, content: "Rules"}]},
        token_usage: %{total: 10}
      }

    assert :ok == Validator.validate(packet)
  end

  test "rejects packets without messages" do
    packet = %Packet{messages: [], sections: %{}, token_usage: %{}}
    assert {:error, :empty_packet_messages} = Validator.validate(packet)
  end

  test "rejects packets with invalid roles" do
    packet = %Packet{
      messages: [%{role: :invalid, content: "bad", metadata: %{}}],
      sections: %{},
      token_usage: %{}
    }

    assert {:error, :invalid_message_role} = Validator.validate(packet)
  end
end
