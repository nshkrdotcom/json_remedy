defmodule JsonRemedy.Utils.Preprocessing do
  @moduledoc false

  @spec extract_code_fence_json_in_string_values(String.t()) :: String.t()
  def extract_code_fence_json_in_string_values(content) when is_binary(content) do
    content
    |> String.replace(
      ~r/(:\s*)"```(?:json)?\s*(\{[\s\S]*?\})\s*```"/iu,
      "\\1\\2"
    )
    |> String.replace(
      ~r/(:\s*)"```(?:json)?\s*(\[[\s\S]*?\])\s*```"/iu,
      "\\1\\2"
    )
  end

  def extract_code_fence_json_in_string_values(content), do: content

  @spec split_truncated_object_key_in_array(String.t()) :: String.t()
  def split_truncated_object_key_in_array(content) when is_binary(content) do
    trimmed = String.trim_trailing(content)
    state = scan_truncated_key_state(trimmed)

    with true <- state.in_string,
         true <- is_integer(state.last_comma_idx),
         true <- is_integer(state.last_string_start),
         true <- state.last_string_start > state.last_comma_idx,
         true <-
           whitespace_only_between?(
             trimmed,
             state.last_comma_idx + 1,
             state.last_string_start - state.last_comma_idx - 1
           ),
         [:brace, :bracket | rest] <- state.last_comma_stack do
      key =
        trimmed
        |> String.slice(
          state.last_string_start + 1,
          String.length(trimmed) - state.last_string_start - 1
        )
        |> String.trim_trailing()

      if key == "" or String.contains?(key, ":") do
        content
      else
        left =
          trimmed
          |> String.slice(0, state.last_comma_idx)
          |> String.trim_trailing()

        escaped_key = escape_json_string(key)
        left <> "}" <> ", [\"" <> escaped_key <> "\"]" <> close_contexts([:bracket | rest])
      end
    else
      _ -> content
    end
  end

  def split_truncated_object_key_in_array(content), do: content

  defp scan_truncated_key_state(content) do
    initial = %{
      stack: [],
      in_string: false,
      escape: false,
      last_comma_idx: nil,
      last_comma_stack: nil,
      last_string_start: nil
    }

    content
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(initial, fn {char, idx}, state ->
      cond do
        state.escape ->
          %{state | escape: false}

        state.in_string and char == "\\" ->
          %{state | escape: true}

        char == "\"" ->
          if state.in_string do
            %{state | in_string: false}
          else
            %{state | in_string: true, last_string_start: idx}
          end

        state.in_string ->
          state

        true ->
          case char do
            "{" ->
              %{state | stack: [:brace | state.stack]}

            "}" ->
              %{state | stack: drop_stack(state.stack, :brace)}

            "[" ->
              %{state | stack: [:bracket | state.stack]}

            "]" ->
              %{state | stack: drop_stack(state.stack, :bracket)}

            "," ->
              if object_directly_in_array?(state.stack) do
                %{state | last_comma_idx: idx, last_comma_stack: state.stack}
              else
                state
              end

            _ ->
              state
          end
      end
    end)
  end

  defp object_directly_in_array?([:brace, :bracket | _]), do: true
  defp object_directly_in_array?(_), do: false

  defp drop_stack([type | rest], type), do: rest
  defp drop_stack(stack, _type), do: stack

  defp whitespace_only_between?(_content, _start, length) when length <= 0, do: true

  defp whitespace_only_between?(content, start, length) do
    content
    |> String.slice(start, length)
    |> String.trim() == ""
  end

  defp escape_json_string(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end

  defp close_contexts(stack) do
    stack
    |> Enum.map(fn
      :brace -> "}"
      :bracket -> "]"
    end)
    |> Enum.join()
  end
end
