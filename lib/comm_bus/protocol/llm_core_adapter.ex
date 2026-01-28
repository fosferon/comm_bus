defmodule CommBus.Protocol.LlmCoreAdapter do
  @moduledoc """
  Default adapter that converts CommBus assemblies into llm_core-friendly packets.
  """

  @behaviour CommBus.Protocol.Adapter

  alias CommBus.{Assembler, Entry, Message}
  alias CommBus.Protocol.{Context, Packet, SectionRoles}

  @impl true
  def assemble(%Context{assembly: nil} = context) do
    assembly =
      Assembler.assemble_prompt(context.conversation, context.entries, context.opts)

    assemble(Context.put_assembly(context, assembly))
  end

  def assemble(%Context{assembly: assembly} = context) when is_map(assembly) do
    sections = Map.get(assembly, :sections, %{})

    messages =
      sections
      |> section_messages(context)
      |> Enum.reject(&empty_content?/1)

    packet = %Packet{
      conversation: context.conversation,
      messages: messages,
      sections: sections,
      included_entries: Map.get(assembly, :included_entries, []),
      excluded_entries: Map.get(assembly, :excluded_entries, []),
      token_usage: Map.get(assembly, :token_usage, %{}),
      metadata: %{
        adapter: __MODULE__,
        section_roles: resolve_section_roles(context),
        generated_at: DateTime.utc_now()
      }
    }

    {:ok, packet}
  end

  defp section_messages(sections, %Context{} = context) do
    section_roles = resolve_section_roles(context)

    pre_sections = [:system, :pre_history]
    post_sections = [:post_history]

    custom_sections =
      sections
      |> Map.keys()
      |> Enum.reject(&(&1 in [:system, :pre_history, :history, :post_history]))
      |> Enum.sort()

    pre_payload =
      Enum.flat_map(pre_sections, fn section ->
        convert_entries(sections, section, section_roles)
      end)

    custom_payload =
      Enum.flat_map(custom_sections, fn section ->
        convert_entries(sections, section, section_roles)
      end)

    history_payload =
      sections
      |> Map.get(:history, context.conversation.messages)
      |> Enum.map(&convert_message/1)

    post_payload =
      Enum.flat_map(post_sections, fn section ->
        convert_entries(sections, section, section_roles)
      end)

    pre_payload ++ custom_payload ++ history_payload ++ post_payload
  end

  defp convert_entries(sections, section, section_roles) do
    entries = Map.get(sections, section, [])

    Enum.map(entries, fn
      %Entry{} = entry ->
        entry_to_message(entry, section_roles |> Map.get(section, :system), section)

      other ->
        other
    end)
  end

  defp entry_to_message(%Entry{} = entry, role, section) do
    metadata =
      (entry.metadata || %{})
      |> Map.put_new(:section, section)
      |> maybe_put(:entry_id, entry.id)
      |> maybe_put(:token_count, entry.token_count)

    %{role: role, content: entry.content, metadata: metadata}
  end

  defp convert_message(%Message{} = message) do
    metadata =
      (message.metadata || %{})
      |> Map.put_new(:section, :history)
      |> maybe_put(:token_count, message.token_count)

    %{role: normalize_role(message.role), content: message.content, metadata: metadata}
  end

  defp normalize_role(role) when role in [:system, :user, :assistant, :tool], do: role
  defp normalize_role(:function), do: :tool

  defp normalize_role(role) when is_binary(role) do
    normalized = role |> String.downcase()

    try do
      String.to_existing_atom(normalized)
    rescue
      ArgumentError -> String.to_atom(normalized)
    end
  end

  defp normalize_role(_), do: :user

  defp empty_content?(%{content: content}) when is_binary(content) do
    String.trim(content) == ""
  end

  defp empty_content?(_), do: false

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp resolve_section_roles(%Context{opts: opts}) do
    overrides = Keyword.get(opts, :section_roles, %{})
    SectionRoles.resolve(overrides)
  end
end
