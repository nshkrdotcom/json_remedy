defmodule JsonRemedy.Utils.StrictModeValidator do
  @moduledoc false

  # Suppress opaque type warnings for MapSet operations
  @dialyzer {:no_opaque, [parse_object: 2, parse_object_entries: 3, check_key: 2]}

  @typep keys_set :: MapSet.t(String.t())

  @spec validate_raw(String.t(), keyword()) :: {:ok, term()} | {:error, String.t()}
  def validate_raw(input, jason_options \\ []) when is_binary(input) do
    case Jason.decode(input, jason_options) do
      {:ok, parsed} ->
        case validate_keys(input) do
          :ok -> {:ok, parsed}
          {:error, reason} -> {:error, reason}
        end

      {:error, _} ->
        {:error, "Strict mode: invalid JSON"}
    end
  end

  defp validate_keys(input) do
    case parse_value(input, skip_ws(input, 0)) do
      {:ok, _pos} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_value(input, pos) do
    pos = skip_ws(input, pos)

    case char_at(input, pos) do
      ?{ -> parse_object(input, pos + 1)
      ?[ -> parse_array(input, pos + 1)
      ?" -> parse_string(input, pos + 1) |> wrap_ok()
      ?t -> parse_literal(input, pos, "true")
      ?f -> parse_literal(input, pos, "false")
      ?n -> parse_literal(input, pos, "null")
      char when char in ?0..?9 or char == ?- -> parse_number(input, pos)
      _ -> {:error, "Strict mode: invalid JSON"}
    end
  end

  defp parse_object(input, pos) do
    pos = skip_ws(input, pos)

    case char_at(input, pos) do
      ?} ->
        {:ok, pos + 1}

      ?" ->
        parse_object_entries(input, pos, MapSet.new())

      _ ->
        {:error, "Strict mode: invalid JSON"}
    end
  end

  @spec parse_object_entries(binary(), non_neg_integer(), keys_set()) ::
          {:ok, pos_integer()} | {:error, String.t()}
  defp parse_object_entries(input, pos, keys) do
    pos = skip_ws(input, pos)

    case char_at(input, pos) do
      ?" ->
        with {:ok, key, pos_after_key} <- parse_string(input, pos + 1),
             :ok <- check_key(key, keys),
             pos_after_colon <- skip_ws(input, pos_after_key),
             ?: <- char_at(input, pos_after_colon),
             {:ok, pos_after_value} <- parse_value(input, pos_after_colon + 1) do
          pos_after_value = skip_ws(input, pos_after_value)

          case char_at(input, pos_after_value) do
            ?, ->
              parse_object_entries(input, pos_after_value + 1, MapSet.put(keys, key))

            ?} ->
              {:ok, pos_after_value + 1}

            _ ->
              {:error, "Strict mode: invalid JSON"}
          end
        else
          _ -> {:error, "Strict mode: invalid JSON"}
        end

      ?} ->
        {:ok, pos + 1}

      _ ->
        {:error, "Strict mode: invalid JSON"}
    end
  end

  defp parse_array(input, pos) do
    pos = skip_ws(input, pos)

    case char_at(input, pos) do
      ?] ->
        {:ok, pos + 1}

      _ ->
        case parse_value(input, pos) do
          {:ok, pos_after_value} ->
            pos_after_value = skip_ws(input, pos_after_value)

            case char_at(input, pos_after_value) do
              ?, -> parse_array(input, pos_after_value + 1)
              ?] -> {:ok, pos_after_value + 1}
              _ -> {:error, "Strict mode: invalid JSON"}
            end

          {:error, _} ->
            {:error, "Strict mode: invalid JSON"}
        end
    end
  end

  defp parse_string(input, pos), do: parse_string(input, pos, "")

  defp parse_string(input, pos, acc) do
    case char_at(input, pos) do
      ?" ->
        {:ok, acc, pos + 1}

      ?\\ ->
        case char_at(input, pos + 1) do
          ?u ->
            parse_string(input, pos + 6, acc <> extract_range(input, pos + 2, 4))

          _ ->
            parse_string(input, pos + 2, acc <> extract_range(input, pos + 1, 1))
        end

      nil ->
        {:error, "Strict mode: invalid JSON"}

      char ->
        parse_string(input, pos + 1, acc <> <<char::utf8>>)
    end
  end

  defp parse_literal(input, pos, literal) do
    if extract_range(input, pos, String.length(literal)) == literal do
      {:ok, pos + String.length(literal)}
    else
      {:error, "Strict mode: invalid JSON"}
    end
  end

  defp parse_number(input, pos) do
    {number, next_pos} = consume_number(input, pos)

    if number == "" do
      {:error, "Strict mode: invalid JSON"}
    else
      {:ok, next_pos}
    end
  end

  defp consume_number(input, pos), do: consume_number(input, pos, "")

  defp consume_number(input, pos, acc) do
    case char_at(input, pos) do
      nil ->
        {acc, pos}

      char when char in ~c"0123456789+-eE." ->
        consume_number(input, pos + 1, acc <> <<char::utf8>>)

      _ ->
        {acc, pos}
    end
  end

  @spec check_key(String.t(), keys_set()) :: :ok | {:error, String.t()}
  defp check_key("", _keys), do: {:error, "Strict mode: empty key"}

  defp check_key(key, keys) do
    if MapSet.member?(keys, key) do
      {:error, "Strict mode: duplicate key"}
    else
      :ok
    end
  end

  defp wrap_ok({:ok, _string, pos}), do: {:ok, pos}
  defp wrap_ok({:error, reason}), do: {:error, reason}

  defp skip_ws(input, pos) do
    case char_at(input, pos) do
      char when char in [?\s, ?\t, ?\n, ?\r] -> skip_ws(input, pos + 1)
      _ -> pos
    end
  end

  defp char_at(input, pos) do
    if pos >= byte_size(input) do
      nil
    else
      :binary.at(input, pos)
    end
  end

  defp extract_range(input, pos, length) do
    if pos >= byte_size(input) do
      ""
    else
      binary_part(input, pos, min(length, byte_size(input) - pos))
    end
  end
end
