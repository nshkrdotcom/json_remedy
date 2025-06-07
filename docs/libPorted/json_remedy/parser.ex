defmodule JsonRemedy.Parser do
  @moduledoc false
  alias JsonRemedy.{Context, Logger, Scanner}

  defstruct input: "",
            position: 0,
            length: 0,
            context: %Context{},
            logger: %Logger{},
            opts: []

  @type state :: %__MODULE__{}

  @string_delimiters ["\"", "'", "“", "”"]

  def parse(input, opts \\ []) do
    clean_input =
      input
      |> String.trim()
      |> maybe_strip_code_fences()

    state = %__MODULE__{
      input: clean_input,
      position: 0,
      length: String.length(clean_input),
      context: %Context{},
      logger: Logger.new(Keyword.get(opts, :logging, false)),
      opts: opts
    }

    case parse_json(state) do
      {:ok, result, final_state} ->
        parse_multiple(result, final_state)

      error ->
        error
    end
  end

  defp maybe_strip_code_fences(input) do
    if String.starts_with?(input, "```json") do
      input
      |> String.slice(7)
      |> String.trim_leading()
      |> String.replace_suffix("```", "")
      |> String.trim_trailing()
    else
      input
    end
  end

  defp parse_multiple(first_result, state) do
    state = %{state | position: Scanner.skip_whitespace(state.input, state.position)}

    if state.position >= state.length do
      {:ok, first_result, state.logger}
    else
      state = %{
        state
        | logger:
            Logger.log(
              state.logger,
              "Found trailing content, assuming multiple JSON objects.",
              state.input,
              state.position
            )
      }

      collect_multiple([first_result], state)
    end
  end

  defp collect_multiple(acc, %{position: pos, length: len} = state) when pos >= len,
    do: {:ok, Enum.reverse(acc), state.logger}

  defp collect_multiple(acc, state) do
    case parse_json(state) do
      {:ok, result, new_state} when result not in [nil, ""] ->
        collect_multiple([result | acc], new_state)

      _ ->
        {:ok, Enum.reverse(acc), state.logger}
    end
  end

  defp parse_json(%{position: pos, length: len} = state) when pos >= len,
    do: {:ok, "", state}

  defp parse_json(state) do
    pos = Scanner.skip_whitespace(state.input, state.position)
    state = %{state | position: pos}

    case Scanner.char_at(state.input, state.position) do
      "{" ->
        parse_object(%{state | position: state.position + 1})

      "[" ->
        parse_array(%{state | position: state.position + 1})

      c when c in @string_delimiters ->
        parse_string(state)

      c when c in ["t", "f", "n"] and state.context.current != :object_key ->
        parse_boolean_or_null(state)

      c when c in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"] or c == "-" ->
        parse_number(state)

      c when c in ["#", "/"] ->
        {:ok, _, new_state} = parse_comment(state)
        parse_json(new_state)

      _ ->
        logger =
          Logger.log(
            state.logger,
            "Skipping extraneous starting character.",
            state.input,
            state.position
          )

        parse_json(%{state | logger: logger, position: state.position + 1})
    end
  end

  defp parse_object(state) do
    parse_object_kv(state, %{})
  end

  defp parse_object_kv(state, acc) do
    pos = Scanner.skip_whitespace(state.input, state.position)
    state = %{state | position: pos}

    case Scanner.char_at(state.input, pos) do
      "}" ->
        {:ok, acc, %{state | position: pos + 1}}

      # FIX: Removed the guard and moved the logic into an `if` statement.
      "]" ->
        if :array in state.context.stack do
          # This handles the `[{]` case correctly. It's a malformed object inside an array.
          # We return the object as-is and let the parent `parse_array` handle the `]`.
          logger =
            Logger.log(state.logger, "Malformed object in array.", state.input, state.position)

          {:ok, acc, %{state | logger: logger}}
        else
          # A `]` outside of an array context is just an error. Treat it as the end of the object.
          logger =
            Logger.log(
              state.logger,
              "Unexpected ']' found. Treating as end of object.",
              state.input,
              state.position
            )

          {:ok, acc, %{state | logger: logger}}
        end

      nil ->
        logger =
          Logger.log(state.logger, "Missing closing '}'. Adding it.", state.input, state.position)

        {:ok, acc, %{state | logger: logger}}

      _ ->
        state = %{state | context: Context.push(state.context, :object_key)}

        case parse_string(state) do
          {:ok, key, state_after_key} ->
            pos = Scanner.skip_whitespace(state_after_key.input, state_after_key.position)
            state_after_key = %{state_after_key | position: pos}

            state_after_colon =
              case Scanner.char_at(state_after_key.input, state_after_key.position) do
                ":" ->
                  %{state_after_key | position: state_after_key.position + 1}

                _ ->
                  logger =
                    Logger.log(
                      state_after_key.logger,
                      "Missing ':' after object key. Inserting it.",
                      state_after_key.input,
                      state_after_key.position
                    )

                  %{state_after_key | logger: logger}
              end

            value_state = %{
              state_after_colon
              | context: Context.pop(state_after_key.context) |> Context.push(:object_value)
            }

            case parse_json(value_state) do
              {:ok, value, state_after_value} ->
                new_acc = Map.put(acc, key, value)

                state_after_value = %{
                  state_after_value
                  | context: Context.pop(state_after_value.context)
                }

                pos =
                  Scanner.skip_whitespace(state_after_value.input, state_after_value.position)

                state_after_value = %{state_after_value | position: pos}

                case Scanner.char_at(state_after_value.input, state_after_value.position) do
                  "," ->
                    parse_object_kv(
                      %{state_after_value | position: state_after_value.position + 1},
                      new_acc
                    )

                  "}" ->
                    {:ok, new_acc,
                     %{state_after_value | position: state_after_value.position + 1}}

                  c when c in @string_delimiters ->
                    logger =
                      Logger.log(
                        state_after_value.logger,
                        "Missing comma between object entries. Inserting it.",
                        state_after_value.input,
                        state_after_value.position
                      )

                    parse_object_kv(%{state_after_value | logger: logger}, new_acc)

                  _ ->
                    {:ok, new_acc, state_after_value}
                end
            end
        end
    end
  end

  defp parse_array(state) do
    state = %{state | context: Context.push(state.context, :array)}
    parse_array_elements(state, [])
  end

  defp parse_array_elements(state, acc) do
    pos = Scanner.skip_whitespace(state.input, state.position)
    state = %{state | position: pos}

    case Scanner.char_at(state.input, pos) do
      "]" ->
        state = %{state | position: pos + 1, context: Context.pop(state.context)}
        {:ok, Enum.reverse(acc), state}

      nil ->
        logger =
          Logger.log(state.logger, "Missing closing ']'. Adding it.", state.input, state.position)

        state = %{state | logger: logger, context: Context.pop(state.context)}
        {:ok, Enum.reverse(acc), state}

      "," ->
        pos = Scanner.skip_whitespace(state.input, pos + 1)

        if Scanner.char_at(state.input, pos) == "]" do
          parse_array_elements(%{state | position: pos}, acc)
        else
          parse_array_elements(%{state | position: pos + 1}, acc)
        end

      _ ->
        case parse_json(state) do
          {:ok, "", state_after_value} ->
            parse_array_elements(state_after_value, acc)

          {:ok, value, state_after_value} ->
            new_acc = [value | acc]
            pos = Scanner.skip_whitespace(state_after_value.input, state_after_value.position)
            state_after_value = %{state_after_value | position: pos}

            case Scanner.char_at(state_after_value.input, state_after_value.position) do
              "," ->
                parse_array_elements(
                  %{state_after_value | position: state_after_value.position + 1},
                  new_acc
                )

              "]" ->
                state_after_value = %{
                  state_after_value
                  | position: state_after_value.position + 1,
                    context: Context.pop(state_after_value.context)
                }

                {:ok, Enum.reverse(new_acc), state_after_value}

              _ ->
                logger =
                  Logger.log(
                    state_after_value.logger,
                    "Missing comma between array elements. Inserting it.",
                    state_after_value.input,
                    state_after_value.position
                  )

                parse_array_elements(%{state_after_value | logger: logger}, new_acc)
            end
        end
    end
  end

  defp parse_string(state) do
    pos = Scanner.skip_whitespace(state.input, state.position)
    start_char = Scanner.char_at(state.input, pos)

    {start_pos, r_delimiter, missing_quotes, logger} =
      case start_char do
        c when c in @string_delimiters ->
          {pos + 1, matching_delimiter(c), false, state.logger}

        _ ->
          new_logger =
            Logger.log(
              state.logger,
              "Missing opening quote for string. Assuming unquoted string.",
              state.input,
              pos
            )

          {pos, "\"", true, new_logger}
      end

    state_before_content = %{state | position: start_pos, logger: logger}

    case do_parse_string(state.input, start_pos, r_delimiter, []) do
      {:ok, content, end_pos} ->
        final_logger =
          if !missing_quotes && Scanner.char_at(state.input, end_pos - 1) != r_delimiter do
            Logger.log(
              state_before_content.logger,
              "Missing closing quote. Adding it.",
              state.input,
              end_pos
            )
          else
            state_before_content.logger
          end

        {:ok, content, %{state_before_content | position: end_pos, logger: final_logger}}

      {:unclosed, content, end_pos} ->
        final_logger =
          Logger.log(
            state_before_content.logger,
            "Unclosed string. Adding closing quote.",
            state.input,
            end_pos
          )

        {:ok, content, %{state_before_content | position: end_pos, logger: final_logger}}
    end
  end

  defp matching_delimiter("“"), do: "”"
  defp matching_delimiter(c), do: c

  defp do_parse_string(input, pos, r_delimiter, acc) do
    len = String.length(input)
    if pos >= len, do: {:unclosed, Enum.reverse(acc) |> IO.iodata_to_binary(), pos}

    case String.at(input, pos) do
      ^r_delimiter ->
        {:ok, Enum.reverse(acc) |> IO.iodata_to_binary(), pos + 1}

      "\\" ->
        case String.at(input, pos + 1) do
          nil ->
            {:unclosed, Enum.reverse(acc) |> IO.iodata_to_binary(), pos}

          "n" ->
            do_parse_string(input, pos + 2, r_delimiter, ["\n" | acc])

          "t" ->
            do_parse_string(input, pos + 2, r_delimiter, ["\t" | acc])

          "r" ->
            do_parse_string(input, pos + 2, r_delimiter, ["\r" | acc])

          "b" ->
            do_parse_string(input, pos + 2, r_delimiter, ["\b" | acc])

          "f" ->
            do_parse_string(input, pos + 2, r_delimiter, ["\f" | acc])

          "\\" ->
            do_parse_string(input, pos + 2, r_delimiter, ["\\" | acc])

          "/" ->
            do_parse_string(input, pos + 2, r_delimiter, ["/" | acc])

          "\"" ->
            do_parse_string(input, pos + 2, r_delimiter, ["\"" | acc])

          "u" ->
            case String.slice(input, pos + 2, 4) do
              hex when byte_size(hex) == 4 ->
                codepoint = String.to_integer(hex, 16)
                do_parse_string(input, pos + 6, r_delimiter, [<<codepoint::utf8>> | acc])

              _ ->
                do_parse_string(input, len, r_delimiter, ["u", "\\" | acc])
            end

          other ->
            do_parse_string(input, pos + 2, r_delimiter, [other, "\\" | acc])
        end

      nil ->
        {:unclosed, Enum.reverse(acc) |> IO.iodata_to_binary(), pos}

      c when c in [":", ","] ->
        {:ok, Enum.reverse(acc) |> IO.iodata_to_binary() |> String.trim_trailing(), pos}

      c when c in ["]", "}"] ->
        {:ok, Enum.reverse(acc) |> IO.iodata_to_binary() |> String.trim_trailing(), pos}

      char ->
        do_parse_string(input, pos + 1, r_delimiter, [char | acc])
    end
  end

  defp parse_number(state) do
    regex = ~r/^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?/

    case Regex.run(regex, String.slice(state.input, state.position..-1//1)) do
      [number_str] ->
        new_pos = state.position + String.length(number_str)

        number =
          if String.contains?(number_str, ".") or String.contains?(number_str, ["e", "E"]) do
            String.to_float(number_str)
          else
            String.to_integer(number_str)
          end

        {:ok, number, %{state | position: new_pos}}

      _ ->
        {:error, "Invalid number", state}
    end
  end

  defp parse_boolean_or_null(state) do
    input_slice = String.slice(state.input, state.position..-1//1)

    cond do
      String.starts_with?(input_slice, "true") ->
        {:ok, true, %{state | position: state.position + 4}}

      String.starts_with?(input_slice, "false") ->
        {:ok, false, %{state | position: state.position + 5}}

      String.starts_with?(input_slice, "null") ->
        {:ok, nil, %{state | position: state.position + 4}}

      String.starts_with?(input_slice, "True") ->
        {:ok, true,
         %{
           state
           | position: state.position + 4,
             logger:
               Logger.log(
                 state.logger,
                 "Replaced 'True' with 'true'",
                 state.input,
                 state.position
               )
         }}

      String.starts_with?(input_slice, "False") ->
        {:ok, false,
         %{
           state
           | position: state.position + 5,
             logger:
               Logger.log(
                 state.logger,
                 "Replaced 'False' with 'false'",
                 state.input,
                 state.position
               )
         }}

      String.starts_with?(input_slice, "None") ->
        {:ok, nil,
         %{
           state
           | position: state.position + 4,
             logger:
               Logger.log(
                 state.logger,
                 "Replaced 'None' with 'null'",
                 state.input,
                 state.position
               )
         }}

      true ->
        {:error, "Invalid literal", state}
    end
  end

  defp parse_comment(state) do
    input_slice = String.slice(state.input, state.position..-1//1)

    cond do
      String.starts_with?(input_slice, "//") ->
        end_of_line = String.split(input_slice, "\n", parts: 2) |> hd() |> String.length()
        {:ok, nil, %{state | position: state.position + end_of_line}}

      String.starts_with?(input_slice, "/*") ->
        case String.split(input_slice, "*/", parts: 2) do
          [_, rest] -> {:ok, nil, %{state | position: state.length - String.length(rest)}}
          _ -> {:ok, nil, %{state | position: state.length}}
        end

      String.starts_with?(input_slice, "#") ->
        end_of_line = String.split(input_slice, "\n", parts: 2) |> hd() |> String.length()
        {:ok, nil, %{state | position: state.position + end_of_line}}

      true ->
        {:error, "Not a comment", state}
    end
  end
end
