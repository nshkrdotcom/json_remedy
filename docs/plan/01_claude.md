# Elixir-Native JSON Repair Approaches

## Core Insight: Rethinking the Problem

Instead of porting imperative parsing logic, we can leverage Elixir's unique strengths:

1. **Pattern Matching on Binaries** - Parse directly with binary patterns
2. **Parser Combinators** - Compose small, focused parsers
3. **Stream Processing** - Handle repairs incrementally
4. **GenServer State Machines** - Model parsing states elegantly
5. **Macro System** - Generate repair rules at compile time

## Approach 1: Binary Pattern Matching Parser

```elixir
defmodule JsonRepair.BinaryParser do
  @moduledoc """
  Ultra-fast JSON repair using binary pattern matching.
  No character-by-character iteration needed!
  """

  # Handle common malformations with direct binary patterns
  def repair(json) when is_binary(json) do
    json
    |> fix_common_patterns()
    |> parse_with_patterns()
  end

  # Fix obvious issues with binary replacement
  defp fix_common_patterns(json) do
    json
    |> String.replace(~r/(['"])([^'"]*)\1\s*:\s*([^'"][^,}\]]*)\b/, ~S("\2": "\3"))  # Unquoted values
    |> String.replace(~r/([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:/, ~S(\1"\2":))      # Unquoted keys
    |> String.replace(~r/,(\s*[}\]])/, "\\1")                                       # Trailing commas
    |> String.replace(~r/([}\]])(\s*)([{\[])/, "\\1,\\2\\3")                      # Missing commas
  end

  # Parse using binary pattern matching
  defp parse_with_patterns(binary), do: parse_value(binary, %{})

  # Object parsing with pattern matching
  defp parse_value(<<"{", rest::binary>>, ctx) do
    parse_object(rest, ctx, %{})
  end

  # Array parsing
  defp parse_value(<<"[", rest::binary>>, ctx) do
    parse_array(rest, ctx, [])
  end

  # String parsing - handle multiple quote types
  defp parse_value(<<quote, rest::binary>>, ctx) when quote in [?", ?', ?", ?"] do
    parse_string(rest, ctx, quote, [])
  end

  # Number parsing
  defp parse_value(<<char, _::binary>> = input, ctx) when char in ?0..?9 or char == ?- do
    parse_number(input, ctx, [])
  end

  # Boolean/null
  defp parse_value(<<"true", rest::binary>>, ctx), do: {true, rest, ctx}
  defp parse_value(<<"false", rest::binary>>, ctx), do: {false, rest, ctx}
  defp parse_value(<<"null", rest::binary>>, ctx), do: {nil, rest, ctx}

  # Repair missing quotes on booleans
  defp parse_value(<<"True", rest::binary>>, ctx), do: {true, rest, add_repair(ctx, "fixed boolean")}
  defp parse_value(<<"False", rest::binary>>, ctx), do: {false, rest, add_repair(ctx, "fixed boolean")}
  defp parse_value(<<"Null", rest::binary>>, ctx), do: {nil, rest, add_repair(ctx, "fixed null")}

  # Skip whitespace
  defp parse_value(<<char, rest::binary>>, ctx) when char in [?\s, ?\t, ?\n, ?\r] do
    parse_value(rest, ctx)
  end

  # Comments - skip them entirely
  defp parse_value(<<"//", rest::binary>>, ctx) do
    skip_line_comment(rest, ctx)
  end
  
  defp parse_value(<<"/*", rest::binary>>, ctx) do
    skip_block_comment(rest, ctx)
  end

  # Parse string with repair capabilities
  defp parse_string(<<quote, rest::binary>>, ctx, quote, acc) do
    # Found closing quote
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), rest, ctx}
  end

  defp parse_string(<<"\\", char, rest::binary>>, ctx, quote, acc) do
    # Handle escape sequences
    escaped = escape_char(char)
    parse_string(rest, ctx, quote, [escaped | acc])
  end

  defp parse_string(<<char, rest::binary>>, ctx, quote, acc) do
    parse_string(rest, ctx, quote, [char | acc])
  end

  # Handle missing closing quote - repair it!
  defp parse_string(<<>>, ctx, _quote, acc) do
    repaired_ctx = add_repair(ctx, "added missing closing quote")
    {acc |> Enum.reverse() |> IO.iodata_to_binary(), <<>>, repaired_ctx}
  end

  # Object parsing with automatic repair
  defp parse_object(<<"}", rest::binary>>, ctx, acc) do
    {acc, rest, ctx}
  end

  defp parse_object(input, ctx, acc) do
    # Parse key
    {key, rest, ctx} = parse_value(input, ctx)
    rest = skip_whitespace(rest)
    
    # Handle missing colon
    {rest, ctx} = case rest do
      <<":", rest::binary>> -> {rest, ctx}
      rest -> {rest, add_repair(ctx, "added missing colon")}
    end
    
    rest = skip_whitespace(rest)
    
    # Parse value
    {value, rest, ctx} = parse_value(rest, ctx)
    rest = skip_whitespace(rest)
    
    # Handle comma or closing brace
    case rest do
      <<",", rest::binary>> ->
        rest = skip_whitespace(rest)
        parse_object(rest, ctx, Map.put(acc, key, value))
      <<"}", rest::binary>> ->
        {Map.put(acc, key, value), rest, ctx}
      rest ->
        # Missing comma - add it and continue
        ctx = add_repair(ctx, "added missing comma")
        parse_object(rest, ctx, Map.put(acc, key, value))
    end
  end

  # Similar pattern for arrays...
  defp parse_array(<<"]", rest::binary>>, ctx, acc) do
    {Enum.reverse(acc), rest, ctx}
  end

  defp parse_array(input, ctx, acc) do
    {value, rest, ctx} = parse_value(input, ctx)
    rest = skip_whitespace(rest)
    
    case rest do
      <<",", rest::binary>> ->
        rest = skip_whitespace(rest)
        parse_array(rest, ctx, [value | acc])
      <<"]", rest::binary>> ->
        {Enum.reverse([value | acc]), rest, ctx}
      rest ->
        # Missing comma
        ctx = add_repair(ctx, "added missing comma in array")
        parse_array(rest, ctx, [value | acc])
    end
  end
end
```

## Approach 2: Parser Combinator Style

```elixir
defmodule JsonRepair.Combinators do
  @moduledoc """
  Build JSON parser from small, composable functions.
  Each combinator handles one concern and can repair specific issues.
  """

  import NimbleParsec

  # Basic combinators with repair capabilities
  def json_value do
    choice([
      json_object(),
      json_array(), 
      json_string(),
      json_number(),
      json_boolean(),
      json_null()
    ])
  end

  def json_object do
    ignore(ascii_char([?{]))
    |> optional(whitespace())
    |> optional(
      json_string()
      |> ignore(optional(whitespace()))
      |> ignore(ascii_char([?:]) |> repair_missing_colon())  # Auto-repair missing colon
      |> ignore(optional(whitespace()))
      |> concat(json_value())
      |> repeat(
        ignore(ascii_char([?,]) |> repair_missing_comma())   # Auto-repair missing comma
        |> ignore(optional(whitespace()))
        |> concat(json_string())
        |> ignore(optional(whitespace()))
        |> ignore(ascii_char([?:]) |> repair_missing_colon())
        |> ignore(optional(whitespace()))
        |> concat(json_value())
      )
    )
    |> ignore(optional(whitespace()))
    |> ignore(ascii_char([?}]) |> repair_missing_brace())    # Auto-repair missing brace
    |> reduce({:build_object, []})
  end

  # Custom combinators that repair while parsing
  defp repair_missing_colon do
    choice([
      ascii_char([?:]),
      empty() |> post_traverse({:add_repair, ["missing colon"]})  # Log repair
    ])
  end

  defp repair_missing_comma do
    choice([
      ascii_char([?,]),
      empty() |> post_traverse({:add_repair, ["missing comma"]})
    ])
  end

  defp repair_missing_brace do
    choice([
      ascii_char([?}]),
      empty() |> post_traverse({:add_repair, ["missing closing brace"]})
    ])
  end

  # Build functions
  defp build_object(items) do
    items
    |> Enum.chunk_every(2)
    |> Map.new(fn [k, v] -> {k, v} end)
  end

  defp add_repair(rest, args, context, line, offset) do
    # Add repair log entry
    repair = %{action: hd(args), line: line, offset: offset}
    {rest, [repair | args], context}
  end
end
```

## Approach 3: Stream-Based Repair Pipeline

```elixir
defmodule JsonRepair.Pipeline do
  @moduledoc """
  Process JSON repair as a stream of transformations.
  Each step in the pipeline fixes one type of issue.
  """

  def repair(json_string) do
    json_string
    |> to_char_stream()
    |> apply_repair_pipeline()
    |> stream_to_result()
  end

  defp to_char_stream(string) do
    string
    |> String.graphemes()
    |> Stream.with_index()
  end

  defp apply_repair_pipeline(stream) do
    stream
    |> fix_quotes()
    |> fix_missing_commas() 
    |> fix_missing_colons()
    |> fix_missing_brackets()
    |> fix_trailing_commas()
    |> validate_and_parse()
  end

  # Each repair function works on the stream
  defp fix_quotes(stream) do
    stream
    |> Stream.transform([], fn {char, pos}, acc ->
      case detect_quote_issue(char, pos, acc) do
        {:fix, fixed_char} -> {[{fixed_char, pos}], update_context(acc, :quote_fixed)}
        {:keep, char} -> {[{char, pos}], acc}
      end
    end)
  end

  defp fix_missing_commas(stream) do
    stream
    |> Stream.chunk_every(3, 1, :discard)  # Look-ahead window
    |> Stream.flat_map(&repair_comma_in_window/1)
  end

  defp repair_comma_in_window([{char1, pos1}, {char2, pos2}, {char3, pos3}] = window) do
    if needs_comma?(char1, char2, char3) do
      [{char1, pos1}, {",", pos1 + 0.5}, {char2, pos2}, {char3, pos3}]
    else
      window
    end
  end

  # Validation as final step
  defp validate_and_parse(stream) do
    stream
    |> Enum.map(fn {char, _pos} -> char end)
    |> Enum.join()
    |> Jason.decode()
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, _} -> {:error, "Could not repair JSON"}
    end
  end
end
```

## Approach 4: GenServer State Machine

```elixir
defmodule JsonRepair.StateMachine do
  @moduledoc """
  Model JSON parsing as a state machine.
  Each state knows how to handle and repair specific syntax.
  """
  
  use GenServer

  # States: :start, :in_object, :in_array, :in_string, :in_number, etc.
  defstruct state: :start, stack: [], result: nil, repairs: [], position: 0

  def repair(json_string) do
    {:ok, pid} = GenServer.start_link(__MODULE__, json_string)
    
    json_string
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.each(fn {char, pos} ->
      GenServer.cast(pid, {:process_char, char, pos})
    end)
    
    GenServer.call(pid, :get_result)
  end

  def handle_cast({:process_char, char, pos}, state) do
    new_state = process_char_in_state(state.state, char, pos, state)
    {:noreply, new_state}
  end

  # Pattern match on current state and character
  defp process_char_in_state(:start, "{", pos, state) do
    %{state | state: :in_object, stack: [:object | state.stack]}
  end

  defp process_char_in_state(:start, "[", pos, state) do
    %{state | state: :in_array, stack: [:array | state.stack]}
  end

  defp process_char_in_state(:in_object, char, pos, state) when char in [?", ?', ?"] do
    %{state | state: :in_string}
  end

  # Handle repairs automatically
  defp process_char_in_state(:in_object, "}", pos, %{expects: :comma} = state) do
    # Missing comma before closing brace - auto-repair
    repairs = [{:added_comma, pos} | state.repairs]
    %{state | state: :start, stack: tl(state.stack), repairs: repairs}
  end

  # ... pattern match for all state transitions with repairs
end
```

## Approach 5: Macro-Generated Repair Rules

```elixir
defmodule JsonRepair.Rules do
  @moduledoc """
  Use macros to generate repair rules at compile time.
  Define repair patterns declaratively.
  """

  # Define repair rules as data
  @repair_rules [
    # {pattern, replacement, description}
    {~r/(['"])([^'"]*)\1\s*:\s*([^'"][^,}\]]*)\b/, ~S("\2": "\3"), "quote unquoted values"},
    {~r/([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:/, ~S(\1"\2":), "quote unquoted keys"},
    {~r/,(\s*[}\]])/, "\\1", "remove trailing commas"},
    {~r/([}\]])(\s*)([{\[])/, "\\1,\\2\\3", "add missing commas between objects"},
    {~r/True\b/, "true", "fix boolean case"},
    {~r/False\b/, "false", "fix boolean case"},
    {~r/Null\b/, "null", "fix null case"}
  ]

  # Generate repair functions at compile time
  for {pattern, replacement, description} <- @repair_rules do
    def unquote(:"apply_#{description |> String.replace(" ", "_")}")(json) do
      case Regex.replace(unquote(pattern), json, unquote(replacement)) do
        ^json -> {:no_change, json}
        repaired -> {:repaired, repaired, unquote(description)}
      end
    end
  end

  def repair_with_rules(json) do
    rules = [
      &apply_quote_unquoted_values/1,
      &apply_quote_unquoted_keys/1,
      &apply_remove_trailing_commas/1,
      &apply_add_missing_commas_between_objects/1,
      &apply_fix_boolean_case/1,
      &apply_fix_null_case/1
    ]

    {final_json, repairs} = 
      Enum.reduce(rules, {json, []}, fn rule, {current_json, repairs} ->
        case rule.(current_json) do
          {:no_change, json} -> {json, repairs}
          {:repaired, json, description} -> {json, [description | repairs]}
        end
      end)

    {:ok, final_json, Enum.reverse(repairs)}
  end
end
```

## Approach 6: Recursive Descent with Pattern Guards

```elixir
defmodule JsonRepair.Elegant do
  @moduledoc """
  The most Elixir-native approach: recursive descent with pattern matching and guards.
  """

  def repair(json) when is_binary(json) do
    case parse_json(json, 0, []) do
      {:ok, result, _pos, repairs} -> {:ok, result, repairs}
      {:error, reason} -> {:error, reason}
    end
  end

  # Parse any JSON value - pattern match on first character
  defp parse_json(<<char, _::binary>> = input, pos, repairs) when char in [?\s, ?\t, ?\n, ?\r] do
    {_ws, new_pos} = consume_whitespace(input, pos)
    parse_json(binary_part(input, new_pos, byte_size(input) - new_pos), new_pos, repairs)
  end

  defp parse_json(<<"{", rest::binary>>, pos, repairs) do
    parse_object(rest, pos + 1, repairs, %{})
  end

  defp parse_json(<<"[", rest::binary>>, pos, repairs) do
    parse_array(rest, pos + 1, repairs, [])
  end

  defp parse_json(<<quote, _::binary>> = input, pos, repairs) when quote in [?", ?', ?", ?"] do
    parse_string(input, pos, repairs)
  end

  defp parse_json(<<char, _::binary>> = input, pos, repairs) when char in ?0..?9 or char == ?- do
    parse_number(input, pos, repairs)
  end

  # Auto-repair common boolean/null variants
  defp parse_json(<<"true", rest::binary>>, pos, repairs), do: {:ok, true, pos + 4, repairs}
  defp parse_json(<<"True", rest::binary>>, pos, repairs), do: {:ok, true, pos + 4, ["fixed True -> true" | repairs]}
  defp parse_json(<<"TRUE", rest::binary>>, pos, repairs), do: {:ok, true, pos + 4, ["fixed TRUE -> true" | repairs]}

  # Pattern match for all variations...

  # Object parsing with intelligent repair
  defp parse_object(input, pos, repairs, acc) do
    case consume_whitespace_and_peek(input, pos) do
      {"}", new_pos} -> 
        {:ok, acc, new_pos + 1, repairs}
      
      {key_start, new_pos} ->
        with {:ok, key, pos_after_key, repairs} <- parse_string_key(input, new_pos, repairs),
             {pos_after_colon, repairs} <- expect_colon(input, pos_after_key, repairs),
             {:ok, value, pos_after_value, repairs} <- parse_json(input, pos_after_colon, repairs),
             {pos_after_comma, repairs} <- handle_object_separator(input, pos_after_value, repairs) do
          
          new_acc = Map.put(acc, key, value)
          parse_object(input, pos_after_comma, repairs, new_acc)
        end
    end
  end

  # Intelligent colon handling with repair
  defp expect_colon(input, pos, repairs) do
    case consume_whitespace_and_peek(input, pos) do
      {":", new_pos} -> {new_pos + 1, repairs}
      {_other, new_pos} -> {new_pos, ["added missing colon" | repairs]}  # Auto-repair!
    end
  end

  # Smart separator handling
  defp handle_object_separator(input, pos, repairs) do
    case consume_whitespace_and_peek(input, pos) do
      {",", new_pos} -> {new_pos + 1, repairs}
      {"}", new_pos} -> {new_pos, repairs}  # End of object
      {_other, new_pos} -> {new_pos, ["added missing comma" | repairs]}  # Auto-repair!
    end
  end
end
```

## Why These Approaches Are More "Elixir-Native"

1. **Binary Pattern Matching**: Directly matches on binary patterns instead of character iteration
2. **Immutable Transformations**: Each step produces new data rather than mutating
3. **Composable Functions**: Small, focused functions that combine elegantly  
4. **Stream Processing**: Natural fit for Elixir's streaming capabilities
5. **State Machines**: GenServer naturally models parsing states
6. **Macro Metaprogramming**: Generate code at compile time for performance
7. **Recursive Descent**: Natural fit for Elixir's recursive, pattern-matched functions

## Performance Benefits

- **Binary matching** is extremely fast in Elixir
- **No character-by-character loops** - process chunks
- **Compile-time optimizations** with macros
- **Tail-call optimization** automatic
- **Parallel processing** possible with streams

## Elegance Benefits

- **Declarative repair rules** instead of imperative logic
- **Pattern matching** makes code self-documenting
- **Composable transformations** easier to test and reason about
- **Automatic memory management** - no manual state tracking

The most elegant approach would likely be **Approach 6** (Recursive Descent with Pattern Guards) combined with **Approach 5** (Macro-Generated Rules) for common repairs. This gives you the performance of binary pattern matching with the expressiveness of declarative repair rules.

Would you like me to develop one of these approaches further?
