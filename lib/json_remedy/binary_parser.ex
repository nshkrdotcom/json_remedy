defmodule JsonRemedy.BinaryParser do
  @moduledoc """
  Ultra-fast JSON repair using binary pattern matching.

  This module uses Elixir's advanced binary pattern matching to parse and repair
  JSON without character-by-character iteration. Each function clause matches
  specific binary patterns, making parsing extremely efficient.
  """

  @type parse_context :: %{
    repairs: [String.t()],
    position: non_neg_integer(),
    strict: boolean()
  }

  @type parse_result :: {term(), binary(), parse_context()}
  @type repair_result :: {:ok, term()} | {:ok, term(), [String.t()]} | {:error, String.t()}

  @doc """
  Main entry point for binary pattern matching repair.

  ## Examples

      iex> JsonRemedy.BinaryParser.repair(~s|{name: "Alice"}|, [])
      {:ok, %{"name" => "Alice"}}

      iex> JsonRemedy.BinaryParser.repair(~s|[1, 2, 3,]|, logging: true)
      {:ok, [1, 2, 3], ["removed trailing comma"]}
  """
  @spec repair(binary(), keyword()) :: repair_result()
  def repair(json, opts \\ []) when is_binary(json) do
    logging = Keyword.get(opts, :logging, false)
    strict = Keyword.get(opts, :strict, true)

    initial_context = %{
      repairs: [],
      position: 0,
      strict: strict
    }

    {preprocessed_json, preprocessing_repairs} = preprocess_json_with_logging(json)

    context_with_preprocessing = %{initial_context |
      repairs: if(logging, do: preprocessing_repairs, else: [])
    }

    # After preprocessing, try Jason first since it's much faster and more reliable
    case Jason.decode(preprocessed_json) do
      {:ok, result} ->
        if logging do
          {:ok, result, Enum.reverse(context_with_preprocessing.repairs)}
        else
          {:ok, result}
        end
      {:error, jason_error} ->
        # Debug: Log why Jason failed after preprocessing
        IO.puts("DEBUG: Jason failed on preprocessed JSON: #{preprocessed_json}")
        IO.puts("DEBUG: Jason error: #{inspect(jason_error)}")

        # Preprocessing didn't fully fix it, use our binary parser
        preprocessed_json
        |> parse_value(context_with_preprocessing)
        |> case do
          {result, <<>>, context} ->
            # Successfully parsed entire input
            if logging do
              {:ok, result, Enum.reverse(context.repairs)}
            else
              {:ok, result}
            end

          {result, remaining, context} ->
            # Parsed successfully but with remaining content
            if String.trim(remaining) == "" do
              if logging do
                {:ok, result, Enum.reverse(context.repairs)}
              else
                {:ok, result}
              end
            else
              {:error, "Unexpected content after JSON: #{inspect(remaining)}"}
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  rescue
    error -> {:error, "Parse error: #{inspect(error)}"}
  end

  # Preprocess the JSON to handle common issues with logging
  defp preprocess_json_with_logging(json) do
    repairs = []

    json = String.trim(json)

    # Remove code fences
    {json, repairs} =
      if String.contains?(json, "```") do
        cleaned = remove_code_fences(json)
        {cleaned, ["removed code fences" | repairs]}
      else
        {json, repairs}
      end

    # Apply pattern fixes with logging
    {json, repairs} = fix_patterns_with_logging(json, repairs)

    {json, Enum.reverse(repairs)}
  end

  defp remove_code_fences(json) do
    json
    |> String.replace(~r/```json\s*/, "")
    |> String.replace(~r/```\s*$/, "")
    |> String.replace(~r/```\s*/, "")
  end

  # Apply fixes with detailed logging - simplified and safe patterns
  defp fix_patterns_with_logging(json, repairs) do
    # Step 1: Fix single quotes to double quotes for strings
    prev_json = json
    json = String.replace(json, ~r/'([^']*)'/, ~S("\1"))
    repairs = if json != prev_json, do: ["converted single quotes to double quotes" | repairs], else: repairs

    # Step 2: Fix missing quotes in common patterns like "Alice, "age" -> "Alice", "age"
    prev_json = json
    json = String.replace(json, ~r/"([^"]*),\s*"([a-zA-Z_][a-zA-Z0-9_]*)"/, ~S("\1", "\2"))
    repairs = if json != prev_json, do: ["fixed missing quote and comma" | repairs], else: repairs

    # Step 3: Fix unquoted keys (only at start of object or after comma)
    prev_json = json
    json = String.replace(json, ~r/([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:/, ~S(\1"\2":))
    repairs = if json != prev_json, do: ["quoted unquoted keys" | repairs], else: repairs

    # Step 4: Fix boolean variants (word boundaries to be safe)
    prev_json = json
    json = String.replace(json, ~r/\bTrue\b/, "true")
    json = String.replace(json, ~r/\bFalse\b/, "false")
    repairs = if json != prev_json, do: ["fixed boolean variants" | repairs], else: repairs

    # Step 5: Fix null variants (word boundaries to be safe)
    prev_json = json
    json = String.replace(json, ~r/\bNone\b/, "null")
    json = String.replace(json, ~r/\bNULL\b/, "null")
    json = String.replace(json, ~r/\bNull\b/, "null")
    repairs = if json != prev_json, do: ["fixed null variants" | repairs], else: repairs

    # Step 6: Fix missing colons between adjacent quoted strings (safe pattern)
    prev_json = json
    json = String.replace(json, ~r/"(\s+)"/, fn match ->
      # Only replace if it's just whitespace between quotes
      if String.trim(match) == ~S("") do
        ~S(": ")
      else
        match
      end
    end)
    repairs = if json != prev_json, do: ["added missing colons" | repairs], else: repairs

    # Step 7: Fix missing commas in arrays (safe pattern for numbers)
    prev_json = json
    json = String.replace(json, ~r/(\d)\s+(\d)/, "\\1, \\2")
    repairs = if json != prev_json, do: ["added missing commas in arrays" | repairs], else: repairs

    # Step 8: Fix trailing commas (this is safe)
    prev_json = json
    json = String.replace(json, ~r/,(\s*[}\]])/, "\\1")
    repairs = if json != prev_json, do: ["removed trailing comma" | repairs], else: repairs

    # Step 9: Fix missing commas between objects/arrays (this is safe)
    prev_json = json
    json = String.replace(json, ~r/([}\]])(\s*)([{\[])/, "\\1,\\2\\3")
    repairs = if json != prev_json, do: ["added missing comma between structures" | repairs], else: repairs

    # That's it! Let the binary parser handle complex cases like unquoted strings

    {json, repairs}
  end

  # Main parsing function - pattern match on binary structure
  @spec parse_value(binary(), parse_context()) :: parse_result() | {:error, String.t()}

  # Skip whitespace
  defp parse_value(<<char, rest::binary>>, ctx) when char in [?\s, ?\t, ?\n, ?\r] do
    parse_value(rest, %{ctx | position: ctx.position + 1})
  end

  # Comments - skip line comments
  defp parse_value(<<"//", rest::binary>>, ctx) do
    {_, new_rest} = skip_line_comment(rest)
    parse_value(new_rest, add_repair(ctx, "removed line comment"))
  end

  # Comments - skip block comments
  defp parse_value(<<"/*", rest::binary>>, ctx) do
    case skip_block_comment(rest) do
      {:ok, new_rest} ->
        parse_value(new_rest, add_repair(ctx, "removed block comment"))
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Object parsing
  defp parse_value(<<"{", rest::binary>>, ctx) do
    parse_object(rest, %{ctx | position: ctx.position + 1}, %{})
  end

  # Array parsing
  defp parse_value(<<"[", rest::binary>>, ctx) do
    parse_array(rest, %{ctx | position: ctx.position + 1}, [])
  end

  # String parsing - handle different quote types
  defp parse_value(<<quote, rest::binary>>, ctx) when quote in [?", ?', ?", ?"] do
    parse_string(rest, ctx, quote, [])
  end

  # Number parsing
  defp parse_value(<<char, _::binary>> = input, ctx) when char in ?0..?9 or char == ?- do
    parse_number(input, ctx, [])
  end

  # Boolean and null literals
  defp parse_value(<<"true", rest::binary>>, ctx) do
    {true, rest, %{ctx | position: ctx.position + 4}}
  end

  defp parse_value(<<"false", rest::binary>>, ctx) do
    {false, rest, %{ctx | position: ctx.position + 5}}
  end

  defp parse_value(<<"null", rest::binary>>, ctx) do
    {nil, rest, %{ctx | position: ctx.position + 4}}
  end

  # Unquoted strings - only in non-strict mode
  defp parse_value(<<char, _::binary>> = input, %{strict: false} = ctx) when char in ?a..?z or char in ?A..?Z or char == ?_ do
    parse_unquoted_string(input, ctx, [])
  end

  # Unquoted strings - also try in strict mode for certain patterns
  defp parse_value(<<char, _::binary>> = input, ctx) when char in ?a..?z or char in ?A..?Z or char == ?_ do
    # Try to parse as unquoted string and repair
    parse_unquoted_string(input, ctx, [])
  end

  # Error case
  defp parse_value(<<char, _::binary>>, ctx) do
    {:error, "Unexpected character '#{<<char>>}' at position #{ctx.position}"}
  end

  defp parse_value(<<>>, _ctx) do
    {:error, "Unexpected end of input"}
  end

  # Object parsing implementation
  defp parse_object(input, ctx, acc) do
    input = skip_whitespace(input, ctx)

    case input do
      <<"}", rest::binary>> ->
        # Empty object or end of object
        {acc, rest, ctx}

      <<>> ->
        # Missing closing brace - repair it
        {acc, <<>>, add_repair(ctx, "added missing closing brace")}

      _ ->
        # Parse key-value pairs
        parse_object_members(input, ctx, acc)
    end
  end

  defp parse_object_members(input, ctx, acc) do
    # Parse key
    case parse_value(input, ctx) do
      {key, rest, new_ctx} when is_binary(key) ->
        rest = skip_whitespace(rest, new_ctx)

        # Handle colon
        {rest, new_ctx} = case rest do
          <<":", rest::binary>> ->
            {skip_whitespace(rest, new_ctx), new_ctx}
          rest ->
            # Missing colon - repair it
            {skip_whitespace(rest, new_ctx), add_repair(new_ctx, "added missing colon")}
        end

        # Parse value
        case parse_value(rest, new_ctx) do
          {value, rest, newer_ctx} ->
            new_acc = Map.put(acc, key, value)
            rest = skip_whitespace(rest, newer_ctx)

            # Handle comma or end
            case rest do
              <<",", rest::binary>> ->
                rest = skip_whitespace(rest, newer_ctx)
                parse_object_members(rest, newer_ctx, new_acc)

              <<"}", rest::binary>> ->
                {new_acc, rest, newer_ctx}

              <<>> ->
                # Missing closing brace
                {new_acc, <<>>, add_repair(newer_ctx, "added missing closing brace")}

              <<"]", _::binary>> ->
                # Object is inside an array and missing closing brace
                {new_acc, rest, add_repair(newer_ctx, "added missing closing brace")}

              _ ->
                # Missing comma - repair and continue
                new_ctx = add_repair(newer_ctx, "added missing comma")
                parse_object_members(rest, new_ctx, new_acc)
            end

          {:error, reason} ->
            {:error, reason}
        end

      {_non_string_key, _rest, _ctx} ->
        {:error, "Object key must be a string"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Array parsing implementation
  defp parse_array(input, ctx, acc) do
    input = skip_whitespace(input, ctx)

    case input do
      <<"]", rest::binary>> ->
        # Empty array or end of array
        {Enum.reverse(acc), rest, ctx}

      <<>> ->
        # Missing closing bracket - repair it
        {Enum.reverse(acc), <<>>, add_repair(ctx, "added missing closing bracket")}

      _ ->
        # Parse array elements
        parse_array_elements(input, ctx, acc)
    end
  end

  defp parse_array_elements(input, ctx, acc) do
    case parse_value(input, ctx) do
      {value, rest, new_ctx} ->
        new_acc = [value | acc]
        rest = skip_whitespace(rest, new_ctx)

        case rest do
          <<",", rest::binary>> ->
            rest = skip_whitespace(rest, new_ctx)
            parse_array_elements(rest, new_ctx, new_acc)

          <<"]", rest::binary>> ->
            {Enum.reverse(new_acc), rest, new_ctx}

          <<>> ->
            # Missing closing bracket
            {Enum.reverse(new_acc), <<>>, add_repair(new_ctx, "added missing closing bracket")}

          _ ->
            # Missing comma - repair and continue
            new_ctx = add_repair(new_ctx, "added missing comma in array")
            parse_array_elements(rest, new_ctx, new_acc)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # String parsing with repair capabilities
  defp parse_string(input, ctx, quote, acc) do
    parse_string_chars(input, ctx, quote, acc)
  end

  defp parse_string_chars(<<char, rest::binary>>, ctx, quote, acc) when char == quote do
    # Found closing quote
    string_value = acc |> Enum.reverse() |> IO.iodata_to_binary()
    {string_value, rest, %{ctx | position: ctx.position + 1}}
  end

  defp parse_string_chars(<<"\\", char, rest::binary>>, ctx, quote, acc) do
    # Handle escape sequences
    escaped = escape_char(char)
    parse_string_chars(rest, %{ctx | position: ctx.position + 2}, quote, [escaped | acc])
  end

  defp parse_string_chars(<<char, rest::binary>>, ctx, quote, acc) do
    # Regular character
    parse_string_chars(rest, %{ctx | position: ctx.position + 1}, quote, [char | acc])
  end

  defp parse_string_chars(<<>>, ctx, _quote, acc) do
    # Missing closing quote - repair it
    string_value = acc |> Enum.reverse() |> IO.iodata_to_binary()
    {string_value, <<>>, add_repair(ctx, "added missing closing quote")}
  end

  # Number parsing
  defp parse_number(input, ctx, acc) do
    parse_number_chars(input, ctx, acc)
  end

  defp parse_number_chars(<<char, rest::binary>>, ctx, acc) when char in ?0..?9 or char in [?-, ?+, ?., ?e, ?E] do
    parse_number_chars(rest, %{ctx | position: ctx.position + 1}, [char | acc])
  end

  defp parse_number_chars(rest, ctx, acc) do
    # End of number
    number_string = acc |> Enum.reverse() |> IO.iodata_to_binary()

    case parse_number_value(number_string) do
      {:ok, number} -> {number, rest, ctx}
      {:error, _} -> {:error, "Invalid number: #{number_string}"}
    end
  end

  # Unquoted string parsing (for non-strict mode or repair)
  defp parse_unquoted_string(<<char, rest::binary>>, ctx, acc) when char in ?a..?z or char in ?A..?Z or char in ?0..?9 or char in [?_, ?-, ?\s] do
    # Allow spaces in unquoted strings (like "New York")
    parse_unquoted_string(rest, %{ctx | position: ctx.position + 1}, [char | acc])
  end

  defp parse_unquoted_string(rest, ctx, acc) do
    # End of unquoted string - trim whitespace
    string_value =
      acc
      |> Enum.reverse()
      |> IO.iodata_to_binary()
      |> String.trim()

    new_ctx = add_repair(ctx, "quoted unquoted string")
    {string_value, rest, new_ctx}
  end

  # Helper functions

  defp skip_whitespace(input, _ctx) do
    skip_whitespace(input)
  end

  defp skip_whitespace(<<char, rest::binary>>) when char in [?\s, ?\t, ?\n, ?\r] do
    skip_whitespace(rest)
  end

  defp skip_whitespace(input), do: input

  defp skip_line_comment(input) do
    skip_line_comment(input, [])
  end

  defp skip_line_comment(<<?\n, rest::binary>>, acc) do
    {Enum.reverse(acc), rest}
  end

  defp skip_line_comment(<<char, rest::binary>>, acc) do
    skip_line_comment(rest, [char | acc])
  end

  defp skip_line_comment(<<>>, acc) do
    {Enum.reverse(acc), <<>>}
  end

  defp skip_block_comment(input) do
    skip_block_comment(input, 0)
  end

  defp skip_block_comment(<<"*/", rest::binary>>, 0) do
    {:ok, rest}
  end

  defp skip_block_comment(<<"/*", rest::binary>>, depth) do
    skip_block_comment(rest, depth + 1)
  end

  defp skip_block_comment(<<"*/", rest::binary>>, depth) when depth > 0 do
    skip_block_comment(rest, depth - 1)
  end

  defp skip_block_comment(<<_char, rest::binary>>, depth) do
    skip_block_comment(rest, depth)
  end

  defp skip_block_comment(<<>>, _depth) do
    {:error, "Unterminated block comment"}
  end

  defp escape_char(?"), do: ?"
  defp escape_char(?\\), do: ?\\
  defp escape_char(?/), do: ?/
  defp escape_char(?b), do: ?\b
  defp escape_char(?f), do: ?\f
  defp escape_char(?n), do: ?\n
  defp escape_char(?r), do: ?\r
  defp escape_char(?t), do: ?\t
  defp escape_char(char), do: char

  defp parse_number_value(string) do
    cond do
      String.contains?(string, ".") or String.contains?(string, "e") or String.contains?(string, "E") ->
        case Float.parse(string) do
          {float, ""} -> {:ok, float}
          _ -> {:error, :invalid_float}
        end

      true ->
        case Integer.parse(string) do
          {int, ""} -> {:ok, int}
          _ -> {:error, :invalid_integer}
        end
    end
  end

  defp add_repair(ctx, message) do
    %{ctx | repairs: [message | ctx.repairs]}
  end
end
