defmodule CommBus.Protocol.Validator do
  @moduledoc """
  Validates assembled protocol packets before they are forwarded to downstream routers.
  """

  alias CommBus.Protocol.Packet

  @allowed_roles [:system, :user, :assistant, :tool]

  @doc "Ensures a packet has well-formed messages, sections, and metadata."
  @spec validate(Packet.t()) :: :ok | {:error, term()}
  def validate(%Packet{} = packet) do
    with :ok <- validate_messages(packet.messages),
         :ok <- validate_sections(packet.sections),
         :ok <- validate_token_usage(packet.token_usage) do
      :ok
    end
  end

  def validate(_), do: {:error, :invalid_packet}

  @doc "Same as validate/1 but raises on failure."
  @spec validate!(Packet.t()) :: Packet.t()
  def validate!(%Packet{} = packet) do
    case validate(packet) do
      :ok -> packet
      {:error, reason} -> raise ArgumentError, "invalid CommBus packet: #{inspect(reason)}"
    end
  end

  defp validate_messages(messages) when is_list(messages) and length(messages) > 0 do
    Enum.reduce_while(messages, :ok, fn message, _acc ->
      case validate_message(message) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_messages(_), do: {:error, :empty_packet_messages}

  defp validate_message(%{role: role, content: content} = message) do
    with {:ok, _normalized_role} <- normalize_role(role),
         true <- is_binary(content) and content != "" do
      metadata = Map.get(message, :metadata, %{})

      if is_map(metadata) do
        :ok
      else
        {:error, :invalid_message_metadata}
      end
    else
      {:error, _} = error -> error
      false -> {:error, :invalid_message_content}
    end
  end

  defp validate_message(_), do: {:error, :invalid_message}

  defp validate_sections(sections) when is_map(sections) do
    if Enum.all?(sections, fn {section, entries} ->
         is_atom(section) and is_list(entries)
       end) do
      :ok
    else
      {:error, :invalid_sections}
    end
  end

  defp validate_sections(_), do: {:error, :invalid_sections}

  defp validate_token_usage(token_usage) when is_map(token_usage), do: :ok
  defp validate_token_usage(_), do: {:error, :invalid_token_usage}

  defp normalize_role(role) when role in @allowed_roles, do: {:ok, role}

  defp normalize_role(role) when is_binary(role) do
    role
    |> String.trim()
    |> String.downcase()
    |> case do
      "" -> {:error, :invalid_message_role}
      "system" -> {:ok, :system}
      "user" -> {:ok, :user}
      "assistant" -> {:ok, :assistant}
      "tool" -> {:ok, :tool}
      _ -> {:error, :invalid_message_role}
    end
  end

  defp normalize_role(_), do: {:error, :invalid_message_role}
end
