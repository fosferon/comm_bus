defmodule CommBus.Protocol.SectionRolesTest do
  use ExUnit.Case, async: false

  alias CommBus.Protocol.SectionRoles

  setup do
    SectionRoles.reset()
    :ok
  end

  test "exposes defaults" do
    assert SectionRoles.get() == SectionRoles.default_roles()
  end

  test "allows registering mappings" do
    assert :ok == SectionRoles.put(:memory, :assistant)
    assert SectionRoles.get().memory == :assistant
  end

  test "can delete and reset mappings" do
    :ok = SectionRoles.put(:memory, :assistant)
    :ok = SectionRoles.delete(:memory)

    refute Map.has_key?(SectionRoles.get(), :memory)

    :ok = SectionRoles.put(:memory, :assistant)
    :ok = SectionRoles.reset()
    refute Map.has_key?(SectionRoles.get(), :memory)
  end

  test "resolves overrides from opts" do
    :ok = SectionRoles.put(:memory, :assistant)

    resolved = SectionRoles.resolve(memory: :tool, pre_history: :assistant)

    assert resolved.memory == :tool
    assert resolved.pre_history == :assistant
  end
end
