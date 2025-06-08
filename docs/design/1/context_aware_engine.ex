defmodule JsonRemedy.ContextAwareEngine do
  @moduledoc """
  Enhanced context tracking with Python-level awareness but Elixir performance.
  
  This module implements the sophisticated context awareness found in Python's
  json_repair while leveraging Elixir's binary pattern matching for performance.
  """

  alias JsonRemedy.Context.JsonContext
  alias JsonRemedy.KnowledgeExtraction

  @type enhanced_context :: %{
    # Core context (existing)
    current: JsonContext.context_value(),
    stack: [JsonContext.context_value()],
    position: non_neg_integer(),
    in_string: boolean(),
    
    # Enhanced context (new)
    last_significant_char: String.t() | nil,
    last_token_type: atom() | nil,
    lookahead_buffer: binary(),
    repair_confidence: float(),
    pattern_cache: map(),
    
    # Python-inspired state tracking
    missing_quotes: boolean(),
    doubled_quotes: boolean(),
    unmatched_delimiter: boolean(),
    string_delimiter: String.t() | nil,
    escape_next: boolean()
  }

  @doc """
  Create enhanced context with Python-level state tracking.
  """
  def new_enhanced_context do
    %{
      # Core context
      current: :root,
      stack: [],
      position: 0,
      in_string: false,
      
      # Enhanced tracking
      last_significant_char: nil,
      last_token_type: nil,
      lookahead_buffer: <<>>,
      repair_confidence: 1.0,
      pattern_cache: %{},
      
      # Python-inspired flags
      missing_quotes: false,
      doubled_quotes: false,
      unmatched_delimiter: false,
      string_delimiter: nil,
      escape_next: false
    }
  end

  @doc """
  Update context with minimal lookahead (3-5 characters).
  Much more efficient than Python's character-by-character approach.
  """
  def update_context_with_lookahead(context, input) do
    position = context.position
    lookahead_size = 5
    
    # Extract lookahead window efficiently
    lookahead = binary_part_safe(input, position, lookahead_size)
    
    %{context | 
      lookahead_buffer: lookahead,
      pattern_cache: update_pattern_cache(context.pattern_cache, lookahead)
    }
  end

  @doc """
  Apply Python-derived patterns with context awareness.
  """
  def apply_patterns(input, context) do
    compiled_patterns = KnowledgeExtraction.compile_patterns()
    
    # Get patterns for current context
    context_patterns = Map.get(compiled_patterns, context.current, [])
    wildcard_patterns = Map.get(compiled_patterns, :any, [])
    
    all_patterns = context_patterns ++ wildcard_patterns
    
    # Apply patterns in priority order
    apply_patterns_recursive(input, context, all_patterns, [])
  end

  defp apply_patterns_recursive(_input, context, [], repairs) do
    {context, Enum.reverse(repairs)}
  end

  defp apply_patterns_recursive(input, context, [pattern | rest], repairs) do
    case try_apply_pattern(input, context, pattern) do
      {:match, new_context, repair} ->
        # Pattern matched, apply repair and continue
        apply_patterns_recursive(input, new_context, rest, [repair | repairs])
      
      :no_match ->
        # Pattern didn't match, try next
        apply_patterns_recursive(input, context, rest, repairs)
    end
  end

  defp try_apply_pattern(input, context, pattern) do
    # Extract current position content for matching
    current_text = binary_part_safe(input, context.position, 20)
    
    case match_pattern(current_text, pattern.matcher) do
      {:match, match_data} ->
        # Pattern matched, check conditions
        case check_repair_conditions(input, context, pattern.repairs, match_data) do
          {:ok, repair_action, new_context} ->
            {:match, new_context, repair_action}
          
          :conditions_not_met ->
            :no_match
        end
      
      :no_match ->
        :no_match
    end
  end

  defp match_pattern(text, {:binary_match, patterns}) do
    # Use Elixir's efficient binary pattern matching
    Enum.find_value(patterns, fn pattern ->
      if String.contains?(text, pattern) do
        {:match, %{pattern: pattern, position: find_pattern_position(text, pattern)}}
      end
    end) || :no_match
  end

  defp match_pattern(text, {:regex_match, regex}) do
    # Fallback to regex for complex patterns
    case Regex.run(regex, text, return: :index) do
      [{start, length}] ->
        match_text = String.slice(text, start, length)
        {:match, %{pattern: match_text, position: start, length: length}}
      
      nil ->
        :no_match
    end
  end

  defp check_repair_conditions(input, context, repairs, match_data) do
    # Try repairs in priority order until one succeeds
    Enum.find_value(repairs, fn repair ->
      if evaluate_condition(input, context, repair.condition_fn, match_data) do
        new_context = apply_repair_to_context(context, repair, match_data)
        repair_action = build_repair_action(repair, match_data, context.position)
        {:ok, repair_action, new_context}
      end
    end) || :conditions_not_met
  end

  # Condition evaluation functions (Python-derived logic)
  
  def followed_by_key?(input, context) do
    # Look ahead to see if pattern is followed by identifier + colon
    lookahead = context.lookahead_buffer
    
    case lookahead do
      <<ws::binary-size(n), rest::binary>> when n <= 3 ->
        # Skip whitespace, check for identifier pattern
        trimmed = String.trim_leading(rest)
        identifier_followed_by_colon?(trimmed)
      
      _ ->
        false
    end
  end

  def looks_like_continuation?(input, context) do
    # Check if this looks like a string continuation vs new key
    last_char = context.last_significant_char
    
    case {last_char, context.current} do
      {"\"", :object_value} ->
        # Might be string continuation in object value
        not followed_by_key?(input, context)
      
      _ ->
        false
    end
  end

  def not_intentional_empty_string?(input, context) do
    # Python's logic for detecting intentional vs accidental doubled quotes
    pos = context.position
    
    # Look at surrounding context
    before = binary_part_safe(input, max(0, pos - 3), 3)
    after_match = binary_part_safe(input, pos + 2, 3)
    
    # Heuristic: if surrounded by word characters, likely accidental
    case {String.last(before), String.first(after_match)} do
      {nil, _} -> true
      {_, nil} -> true
      {b, a} when b in ~w(a b c d e f g h i j k l m n o p q r s t u v w x y z) and
                   a in ~w(a b c d e f g h i j k l m n o p q r s t u v w x y z) -> true
      _ -> false
    end
  end

  def valid_identifier?(input, context) do
    # Check if text at position is a valid JavaScript identifier
    text = binary_part_safe(input, context.position, 10)
    
    case text do
      <<first::utf8, rest::binary>> when first in ?a..?z or first in ?A..?Z or first == ?_ ->
        # Valid identifier start
        identifier_chars?(rest)
      
      _ ->
        false
    end
  end

  def inside_string_literal?(input, context) do
    # Use enhanced context tracking instead of recalculating
    context.in_string
  end

  def word_boundary?(input, context) do
    # Check if match is at word boundary
    pos = context.position
    before_char = if pos > 0, do: binary_part_safe(input, pos - 1, 1), else: " "
    
    # Word boundary if preceded by non-identifier character
    not identifier_char?(before_char)
  end

  # Helper functions

  defp binary_part_safe(binary, start, length) do
    max_length = byte_size(binary) - start
    actual_length = min(length, max(0, max_length))
    
    if actual_length > 0 do
      binary_part(binary, start, actual_length)
    else
      <<>>
    end
  end

  defp find_pattern_position(text, pattern) do
    case :binary.match(text, pattern) do
      {pos, _len} -> pos
      :nomatch -> 0
    end
  end

  defp identifier_followed_by_colon?(text) do
    # Check for pattern: identifier + optional whitespace + colon
    case text do
      <<first::utf8, rest::binary>> when first in ?a..?z or first in ?A..?Z or first == ?_ ->
        case consume_identifier(rest) do
          {_id, remainder} ->
            remainder
            |> String.trim_leading()
            |> String.starts_with?(":")
          
          :no_identifier ->
            false
        end
      
      _ ->
        false
    end
  end

  defp consume_identifier(binary) do
    consume_identifier(binary, <<>>)
  end

  defp consume_identifier(<<char::utf8, rest::binary>>, acc) 
       when char in ?a..?z or char in ?A..?Z or char in ?0..?9 or char == ?_ do
    consume_identifier(rest, <<acc::binary, char::utf8>>)
  end

  defp consume_identifier(remainder, <<>>) do
    :no_identifier
  end

  defp consume_identifier(remainder, acc) do
    {acc, remainder}
  end

  defp identifier_chars?(binary) do
    identifier_chars?(binary, true)
  end

  defp identifier_chars?(<<>>, found_any) do
    found_any
  end

  defp identifier_chars?(<<char::utf8, rest::binary>>, found_any) 
       when char in ?a..?z or char in ?A..?Z or char in ?0..?9 or char == ?_ do
    identifier_chars?(rest, true)
  end

  defp identifier_chars?(_, _) do
    false
  end

  defp identifier_char?(<<char::utf8>>) 
       when char in ?a..?z or char in ?A..?Z or char in ?0..?9 or char == ?_ do
    true
  end

  defp identifier_char?(_) do
    false
  end

  defp evaluate_condition(input, context, {:function, module, function}, match_data) do
    apply(module, function, [input, context])
  end

  defp evaluate_condition(input, context, condition_fn, match_data) when is_function(condition_fn) do
    condition_fn.(input, context)
  end

  defp apply_repair_to_context(context, repair, match_data) do
    # Update context based on repair action
    case repair.action do
      :insert_comma ->
        %{context | last_significant_char: ",", last_token_type: :comma}
      
      :normalize_to_double_quotes ->
        %{context | string_delimiter: "\""}
      
      :quote_identifier ->
        %{context | last_token_type: :quoted_key}
      
      _ ->
        context
    end
  end

  defp build_repair_action(repair, match_data, position) do
    %{
      layer: :python_enhanced,
      action: repair.action,
      position: position,
      pattern: match_data.pattern,
      confidence: calculate_confidence(repair, match_data)
    }
  end

  defp calculate_confidence(repair, match_data) do
    # Simple confidence based on priority (lower priority = higher confidence)
    base_confidence = 1.0 - (repair.priority * 0.1)
    
    # Adjust based on pattern specificity
    pattern_bonus = if byte_size(match_data.pattern) > 3, do: 0.1, else: 0.0
    
    min(1.0, base_confidence + pattern_bonus)
  end

  defp update_pattern_cache(cache, lookahead) do
    # Cache commonly used pattern matches to avoid recomputation
    key = :crypto.hash(:md5, lookahead) |> Base.encode16()
    
    if Map.has_key?(cache, key) do
      cache
    else
      # Add basic pattern detection to cache
      patterns = %{
        has_quotes: String.contains?(lookahead, "\""),
        has_comma: String.contains?(lookahead, ","),
        has_colon: String.contains?(lookahead, ":"),
        has_brace: String.contains?(lookahead, "{") or String.contains?(lookahead, "}"),
        whitespace_only: String.trim(lookahead) == ""
      }
      
      Map.put(cache, key, patterns)
    end
  end
end
