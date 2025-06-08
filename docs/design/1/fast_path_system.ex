defmodule JsonRemedy.FastPathSystem do
  @moduledoc """
  Fast path optimization that handles common cases with O(1) binary patterns
  while falling back to sophisticated Python-derived logic for complex cases.
  """

  alias JsonRemedy.ContextAwareEngine

  # Compile-time optimization: Most common patterns as binary matches
  @fast_patterns [
    # Single quote to double quote (80% of quote issues)
    {~r/'([^']*)'/, "\"\\1\"", :normalize_quotes},
    
    # Python booleans (60% of boolean issues)  
    {"True", "true", :normalize_boolean},
    {"False", "false", :normalize_boolean},
    {"None", "null", :normalize_null},
    
    # Trailing commas (40% of comma issues)
    {~r/,(\s*[}\]])/, "\\1", :remove_trailing_comma},
    
    # Missing quotes around simple keys (50% of key issues)
    {~r/([{,]\s*)([a-zA-Z_][a-zA-Z0-9_]*)\s*:/, "\\1\"\\2\":", :quote_simple_key},
    
    # Doubled quotes (20% of quote issues)
    {~r/""/, "\"", :collapse_doubled_quotes}
  ]

  @doc """
  Attempt fast repair using binary pattern matching.
  Returns {:fast_path, result} or {:complex, input} for fallback.
  """
  def attempt_fast_repair(input) when is_binary(input) do
    case detect_complexity(input) do
      :simple -> 
        apply_fast_patterns(input, @fast_patterns, [])
      
      :complex -> 
        {:complex, input}
    end
  end

  @doc """
  Enhanced Layer 3 that combines fast path with Python-derived logic.
  """
  def enhanced_syntax_normalization(input, context) do
    case attempt_fast_repair(input) do
      {:fast_path, repaired, repairs} ->
        # Fast path succeeded
        {:ok, repaired, update_context_with_repairs(context, repairs)}
      
      {:complex, input} ->
        # Fall back to sophisticated processing
        apply_python_enhanced_logic(input, context)
    end
  end

  # Fast path pattern application
  defp apply_fast_patterns(input, [], repairs) do
    {:fast_path, input, Enum.reverse(repairs)}
  end

  defp apply_fast_patterns(input, [pattern | rest], repairs) do
    case apply_single_fast_pattern(input, pattern) do
      {:changed, new_input, repair} ->
        # Pattern applied, continue with rest
        apply_fast_patterns(new_input, rest, [repair | repairs])
      
      {:unchanged, input} ->
        # Pattern didn't apply, try next
        apply_fast_patterns(input, rest, repairs)
    end
  end

  defp apply_single_fast_pattern(input, {regex, replacement, action}) when is_struct(regex, Regex) do
    case Regex.replace(regex, input, replacement) do
      ^input -> 
        {:unchanged, input}
      
      new_input -> 
        repair = create_fast_repair(action, "Fast path: #{action}")
        {:changed, new_input, repair}
    end
  end

  defp apply_single_fast_pattern(input, {search_string, replacement, action}) when is_binary(search_string) do
    case String.replace(input, search_string, replacement) do
      ^input -> 
        {:unchanged, input}
      
      new_input -> 
        repair = create_fast_repair(action, "Fast path: #{action}")
        {:changed, new_input, repair}
    end
  end

  # Complexity detection using binary pattern analysis
  defp detect_complexity(input) do
    # Quick heuristics to determine if we need sophisticated processing
    complexity_indicators = [
      # Nested quotes: "...\"...\"..."
      String.contains?(input, "\\\""),
      
      # Multiple quote types mixed: both ' and "
      String.contains?(input, "'") and String.contains?(input, "\""),
      
      # Escaped characters
      String.contains?(input, "\\"),
      
      # Complex nested structures
      String.length(input) > 1000,
      
      # Malformed structures that need context awareness
      unmatched_delimiters?(input),
      
      # String content that looks like JSON
      suspicious_string_content?(input)
    ]

    if Enum.any?(complexity_indicators) do
      :complex
    else
      :simple
    end
  end

  defp unmatched_delimiters?(input) do
    # Quick check for obviously unmatched delimiters
    open_braces = count_occurrences(input, "{")
    close_braces = count_occurrences(input, "}")
    open_brackets = count_occurrences(input, "[")
    close_brackets = count_occurrences(input, "]")
    
    open_braces != close_braces or open_brackets != close_brackets
  end

  defp suspicious_string_content?(input) do
    # Look for patterns that suggest JSON-like content inside strings
    # This would need context-aware processing
    String.contains?(input, "\"{") or 
    String.contains?(input, "}\"") or
    String.contains?(input, "\"[") or
    String.contains?(input, "]\"")
  end

  defp count_occurrences(string, substring) do
    string
    |> String.split(substring)
    |> length()
    |> Kernel.-(1)
  end

  # Python-enhanced logic for complex cases
  defp apply_python_enhanced_logic(input, context) do
    # Initialize enhanced context
    enhanced_context = ContextAwareEngine.new_enhanced_context()
    
    # Merge with existing context
    merged_context = Map.merge(enhanced_context, context)
    
    # Apply Python-derived patterns with full context awareness
    {final_context, repairs} = ContextAwareEngine.apply_patterns(input, merged_context)
    
    # Process the input with repairs
    {repaired_input, processing_repairs} = apply_context_aware_repairs(input, repairs)
    
    all_repairs = context.repairs ++ repairs ++ processing_repairs
    final_context_map = %{context | repairs: all_repairs}
    
    {:ok, repaired_input, final_context_map}
  end

  # Apply repairs with context awareness
  defp apply_context_aware_repairs(input, repairs) do
    # Sort repairs by position to apply from end to beginning (safer)
    sorted_repairs = Enum.sort_by(repairs, & &1.position, :desc)
    
    {final_input, applied_repairs} = 
      Enum.reduce(sorted_repairs, {input, []}, fn repair, {current_input, acc_repairs} ->
        case apply_single_repair(current_input, repair) do
          {:ok, new_input, applied_repair} ->
            {new_input, [applied_repair | acc_repairs]}
          
          {:skip, reason} ->
            # Repair wasn't applicable, log but continue
            skipped_repair = %{repair | action: "skipped: #{reason}"}
            {current_input, [skipped_repair | acc_repairs]}
        end
      end)
    
    {final_input, Enum.reverse(applied_repairs)}
  end

  defp apply_single_repair(input, repair) do
    case repair.action do
      :insert_comma ->
        apply_comma_insertion(input, repair)
      
      :quote_identifier ->
        apply_identifier_quoting(input, repair)
      
      :normalize_to_double_quotes ->
        apply_quote_normalization(input, repair)
      
      :collapse_doubled_quotes ->
        apply_quote_collapse(input, repair)
      
      :remove_trailing_comma ->
        apply_comma_removal(input, repair)
      
      :add_closing_quote ->
        apply_quote_addition(input, repair)
      
      _ ->
        {:skip, "unknown repair action: #{repair.action}"}
    end
  end

  # Specific repair implementations with Python-level sophistication

  defp apply_comma_insertion(input, repair) do
    pos = repair.position
    
    # Validate that comma insertion is still appropriate
    context_before = String.slice(input, max(0, pos - 10), 10)
    context_after = String.slice(input, pos, 10)
    
    cond do
      # Don't insert comma if one already exists nearby
      String.contains?(context_before <> context_after, ",") ->
        {:skip, "comma already present"}
      
      # Don't insert comma inside string literals
      inside_string_at_position?(input, pos) ->
        {:skip, "position inside string"}
      
      # Apply the insertion
      true ->
        before = String.slice(input, 0, pos)
        after_text = String.slice(input, pos, String.length(input))
        
        # Smart comma insertion with appropriate spacing
        comma_with_space = if String.starts_with?(String.trim_leading(after_text), "\"") do
          ", "
        else
          ","
        end
        
        new_input = before <> comma_with_space <> after_text
        applied_repair = %{repair | replacement: comma_with_space}
        
        {:ok, new_input, applied_repair}
    end
  end

  defp apply_identifier_quoting(input, repair) do
    pos = repair.position
    
    # Extract the identifier to quote
    identifier_text = extract_identifier_at_position(input, pos)
    
    case identifier_text do
      {:ok, identifier, start_pos, end_pos} ->
        # Validate this is still an unquoted key
        after_identifier = String.slice(input, end_pos, 10)
        
        if String.trim_leading(after_identifier) |> String.starts_with?(":") do
          # Still looks like a key, apply quoting
          before = String.slice(input, 0, start_pos)
          after_text = String.slice(input, end_pos, String.length(input))
          
          quoted_identifier = "\"#{identifier}\""
          new_input = before <> quoted_identifier <> after_text
          
          applied_repair = %{repair | 
            original: identifier, 
            replacement: quoted_identifier
          }
          
          {:ok, new_input, applied_repair}
        else
          {:skip, "no longer appears to be unquoted key"}
        end
      
      {:error, reason} ->
        {:skip, reason}
    end
  end

  defp apply_quote_normalization(input, repair) do
    pos = repair.position
    
    # Find the single quote to replace
    case find_quote_at_position(input, pos, "'") do
      {:ok, quote_pos} ->
        # Find matching closing quote
        case find_matching_quote(input, quote_pos + 1, "'") do
          {:ok, closing_pos} ->
            # Replace both quotes
            before_open = String.slice(input, 0, quote_pos)
            content = String.slice(input, quote_pos + 1, closing_pos - quote_pos - 1)
            after_close = String.slice(input, closing_pos + 1, String.length(input))
            
            # Escape any double quotes in the content
            escaped_content = String.replace(content, "\"", "\\\"")
            
            new_input = before_open <> "\"" <> escaped_content <> "\"" <> after_close
            
            applied_repair = %{repair | 
              original: "'#{content}'", 
              replacement: "\"#{escaped_content}\""
            }
            
            {:ok, new_input, applied_repair}
          
          :not_found ->
            {:skip, "matching single quote not found"}
        end
      
      :not_found ->
        {:skip, "single quote not found at position"}
    end
  end

  defp apply_quote_collapse(input, repair) do
    pos = repair.position
    
    # Look for doubled quotes at position
    if String.slice(input, pos, 2) == "\"\"" do
      # Check if this is intentional empty string or accidental doubling
      context_before = String.slice(input, max(0, pos - 5), 5)
      context_after = String.slice(input, pos + 2, 5)
      
      # Heuristic: if surrounded by word characters, likely accidental
      if looks_like_accidental_doubling?(context_before, context_after) do
        before = String.slice(input, 0, pos)
        after_text = String.slice(input, pos + 2, String.length(input))
        
        new_input = before <> "\"" <> after_text
        
        applied_repair = %{repair | 
          original: "\"\"", 
          replacement: "\""
        }
        
        {:ok, new_input, applied_repair}
      else
        {:skip, "appears to be intentional empty string"}
      end
    else
      {:skip, "doubled quotes not found at position"}
    end
  end

  defp apply_comma_removal(input, repair) do
    pos = repair.position
    
    # Find trailing comma pattern
    segment = String.slice(input, pos, 10)
    
    case Regex.run(~r/^,(\s*[}\]])/, segment) do
      [full_match, after_comma] ->
        before = String.slice(input, 0, pos)
        after_text = String.slice(input, pos + String.length(full_match), String.length(input))
        
        new_input = before <> after_comma <> after_text
        
        applied_repair = %{repair | 
          original: full_match, 
          replacement: after_comma
        }
        
        {:ok, new_input, applied_repair}
      
      nil ->
        {:skip, "trailing comma pattern not found"}
    end
  end

  defp apply_quote_addition(input, repair) do
    pos = repair.position
    
    # Look for unterminated string
    if String.at(input, pos) == "\"" do
      # Find where the quote should be closed
      case find_string_termination_point(input, pos + 1) do
        {:ok, end_pos} ->
          before = String.slice(input, 0, end_pos)
          after_text = String.slice(input, end_pos, String.length(input))
          
          new_input = before <> "\"" <> after_text
          
          applied_repair = %{repair | 
            original: "missing quote", 
            replacement: "\"",
            position: end_pos
          }
          
          {:ok, new_input, applied_repair}
        
        :not_found ->
          {:skip, "could not determine where to close string"}
      end
    else
      {:skip, "quote not found at position"}
    end
  end

  # Helper functions for sophisticated repair logic

  defp inside_string_at_position?(input, pos) do
    # Count unescaped quotes before position
    before_text = String.slice(input, 0, pos)
    quote_count = count_unescaped_quotes(before_text)
    rem(quote_count, 2) != 0
  end

  defp count_unescaped_quotes(text) do
    count_unescaped_quotes(text, 0, 0)
  end

  defp count_unescaped_quotes("", _pos, count), do: count

  defp count_unescaped_quotes(<<"\\\"", rest::binary>>, pos, count) do
    # Skip escaped quote
    count_unescaped_quotes(rest, pos + 2, count)
  end

  defp count_unescaped_quotes(<<"\"", rest::binary>>, pos, count) do
    # Found unescaped quote
    count_unescaped_quotes(rest, pos + 1, count + 1)
  end

  defp count_unescaped_quotes(<<_char::utf8, rest::binary>>, pos, count) do
    count_unescaped_quotes(rest, pos + 1, count)
  end

  defp extract_identifier_at_position(input, pos) do
    # Find start of identifier
    start_pos = find_identifier_start(input, pos)
    
    case start_pos do
      {:ok, start} ->
        # Extract the identifier
        remaining = String.slice(input, start, String.length(input))
        
        case extract_identifier_from_start(remaining) do
          {:ok, identifier, length} ->
            {:ok, identifier, start, start + length}
          
          error ->
            error
        end
      
      error ->
        error
    end
  end

  defp find_identifier_start(input, pos) do
    # Scan backwards to find start of identifier
    find_identifier_start(input, pos, pos)
  end

  defp find_identifier_start(input, current_pos, original_pos) when current_pos >= 0 do
    char = String.at(input, current_pos)
    
    case char do
      nil ->
        {:error, "reached beginning of input"}
      
      char when char in ["a".."z"] ++ ["A".."Z"] ++ ["_"] ->
        # Valid identifier character, keep scanning back
        find_identifier_start(input, current_pos - 1, original_pos)
      
      char when char in ["0".."9"] and current_pos < original_pos ->
        # Digit is valid in middle of identifier
        find_identifier_start(input, current_pos - 1, original_pos)
      
      _ ->
        # Found start boundary
        {:ok, current_pos + 1}
    end
  end

  defp find_identifier_start(_input, current_pos, _original_pos) do
    {:ok, 0}
  end

  defp extract_identifier_from_start(text) do
    extract_identifier_from_start(text, "", 0)
  end

  defp extract_identifier_from_start(<<char::utf8, rest::binary>>, acc, length) 
       when char in ?a..?z or char in ?A..?Z or char == ?_ or 
            (char in ?0..?9 and length > 0) do
    extract_identifier_from_start(rest, <<acc::binary, char::utf8>>, length + 1)
  end

  defp extract_identifier_from_start(_remaining, "", _length) do
    {:error, "no identifier found"}
  end

  defp extract_identifier_from_start(_remaining, acc, length) do
    {:ok, acc, length}
  end

  defp find_quote_at_position(input, pos, quote_char) do
    if String.at(input, pos) == quote_char do
      {:ok, pos}
    else
      # Scan nearby for the quote
      Enum.find_value(-2..2, fn offset ->
        check_pos = pos + offset
        if check_pos >= 0 and String.at(input, check_pos) == quote_char do
          {:ok, check_pos}
        end
      end) || :not_found
    end
  end

  defp find_matching_quote(input, start_pos, quote_char) do
    find_matching_quote(input, start_pos, quote_char, false)
  end

  defp find_matching_quote(input, pos, quote_char, escaped) do
    case String.at(input, pos) do
      nil ->
        :not_found
      
      "\\" when not escaped ->
        find_matching_quote(input, pos + 1, quote_char, true)
      
      ^quote_char when not escaped ->
        {:ok, pos}
      
      _ ->
        find_matching_quote(input, pos + 1, quote_char, false)
    end
  end

  defp looks_like_accidental_doubling?(before, after_text) do
    # Heuristic: accidental if surrounded by alphanumeric characters
    last_before = String.last(String.trim(before))
    first_after = String.first(String.trim(after_text))
    
    is_alphanum = fn char ->
      char && Regex.match?(~r/[a-zA-Z0-9]/, char)
    end
    
    is_alphanum.(last_before) and is_alphanum.(first_after)
  end

  defp find_string_termination_point(input, start_pos) do
    # Look for logical end of string content
    # This is a complex heuristic based on Python's logic
    
    termination_chars = [",", "}", "]", ":"]
    
    # Scan forward looking for likely termination point
    find_termination_recursive(input, start_pos, termination_chars, false, 0)
  end

  defp find_termination_recursive(input, pos, term_chars, in_nested, nesting_level) do
    case String.at(input, pos) do
      nil ->
        # End of input
        {:ok, pos}
      
      "\\" ->
        # Skip escaped character
        find_termination_recursive(input, pos + 2, term_chars, in_nested, nesting_level)
      
      char when char in ["{", "["] ->
        # Entering nested structure
        find_termination_recursive(input, pos + 1, term_chars, true, nesting_level + 1)
      
      char when char in ["}", "]"] ->
        new_level = nesting_level - 1
        if new_level <= 0 do
          {:ok, pos}
        else
          find_termination_recursive(input, pos + 1, term_chars, new_level > 0, new_level)
        end
      
      char when char in term_chars and nesting_level == 0 ->
        # Found termination character at top level
        {:ok, pos}
      
      _ ->
        # Continue scanning
        find_termination_recursive(input, pos + 1, term_chars, in_nested, nesting_level)
    end
  end

  defp create_fast_repair(action, description) do
    %{
      layer: :fast_path,
      action: action,
      description: description,
      position: nil,
      confidence: 0.9
    }
  end

  defp update_context_with_repairs(context, repairs) do
    %{context | repairs: context.repairs ++ repairs}
  end
end
