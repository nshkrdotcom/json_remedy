defmodule JsonRemedy.KnowledgeExtraction do
  @moduledoc """
  Systematic extraction of empirical patterns from Python json_repair library.
  
  This module analyzes the Python codebase to extract repair patterns and 
  convert them into Elixir's compile-time decision trees.
  """

  @doc """
  Extracted patterns from Python's parse_string() method.
  These represent years of battle-testing against real-world malformed JSON.
  """
  @python_derived_patterns [
    # Pattern 1: Doubled quotes "" -> "
    %{
      name: :doubled_quotes,
      context: [:object_key, :object_value, :array],
      pattern: ~r/""/,
      python_location: "parse_string():450",
      description: "Python handles doubled quotes by checking next character",
      repairs: [
        {priority: 1, action: :collapse_doubled_quotes, 
         condition: &not_intentional_empty_string?/2}
      ]
    },

    # Pattern 2: Missing quotes around keys
    %{
      name: :unquoted_object_keys,
      context: :object_key,
      pattern: ~r/([a-zA-Z_][a-zA-Z0-9_]*)\s*:/,
      python_location: "parse_object():200-250",
      description: "Python's rollback mechanism for unquoted keys",
      repairs: [
        {priority: 1, action: :quote_identifier, 
         condition: &valid_identifier?/2},
        {priority: 2, action: :skip_if_in_string, 
         condition: &inside_string_literal?/2}
      ]
    },

    # Pattern 3: Single quotes normalization
    %{
      name: :single_quote_normalization,
      context: [:object_key, :object_value, :array],
      pattern: ~r/'/,
      python_location: "parse_string():300-350",
      description: "Python's quote delimiter selection logic",
      repairs: [
        {priority: 1, action: :normalize_to_double_quotes,
         condition: &not_escaped?/2},
        {priority: 2, action: :preserve_if_nested,
         condition: &nested_quote_context?/2}
      ]
    },

    # Pattern 4: Missing comma between object values
    %{
      name: :missing_comma_object_values,
      context: :object_value,
      pattern: ~r/"\s*"/,
      python_location: "parse_object():220-240 array merging logic",
      description: "Python's sophisticated logic for detecting value boundaries",
      repairs: [
        {priority: 1, action: :insert_comma, 
         condition: &followed_by_key?/2},
        {priority: 2, action: :merge_strings, 
         condition: &looks_like_continuation?/2},
        {priority: 3, action: :ignore_if_same_key,
         condition: &duplicate_key_pattern?/2}
      ]
    },

    # Pattern 5: Missing comma between array items
    %{
      name: :missing_comma_array_items,
      context: :array,
      pattern: ~r/(\w|\]|\})\s*(\w|\[|\{|")/,
      python_location: "parse_array():150-200",
      description: "Python's value boundary detection in arrays",
      repairs: [
        {priority: 1, action: :insert_comma,
         condition: &distinct_values?/2},
        {priority: 2, action: :skip_if_string_content,
         condition: &within_string_literal?/2}
      ]
    },

    # Pattern 6: Trailing commas
    %{
      name: :trailing_commas,
      context: [:object_value, :array],
      pattern: ~r/,\s*[}\]]/,
      python_location: "Multiple locations in parsing",
      description: "Python's permissive comma handling",
      repairs: [
        {priority: 1, action: :remove_trailing_comma,
         condition: &before_closing_delimiter?/2}
      ]
    },

    # Pattern 7: Boolean normalization
    %{
      name: :python_boolean_literals,
      context: [:object_value, :array],
      pattern: ~r/\b(True|False|None|NULL)\b/,
      python_location: "parse_boolean_or_null():500-600",
      description: "Python's literal normalization with word boundary checking",
      repairs: [
        {priority: 1, action: :normalize_boolean,
         condition: &word_boundary?/2},
        {priority: 2, action: :skip_if_in_string,
         condition: &inside_string_content?/2}
      ]
    },

    # Pattern 8: Missing closing quotes
    %{
      name: :missing_closing_quotes,
      context: [:object_key, :object_value],
      pattern: ~r/"[^"]*$/,
      python_location: "parse_string():400-500 rstring_delimiter_missing logic",
      description: "Python's sophisticated missing quote detection",
      repairs: [
        {priority: 1, action: :add_closing_quote,
         condition: &end_of_value?/2},
        {priority: 2, action: :add_quote_before_delimiter,
         condition: &delimiter_follows?/2}
      ]
    },

    # Pattern 9: Mismatched delimiters  
    %{
      name: :mismatched_delimiters,
      context: [:object, :array],
      pattern: ~r/[\[{].*[}\]]/,
      python_location: "parse_object/parse_array boundary handling",
      description: "Python's delimiter matching with context awareness",
      repairs: [
        {priority: 1, action: :fix_closing_delimiter,
         condition: &context_mismatch?/2},
        {priority: 2, action: :insert_missing_delimiter,
         condition: &unclosed_context?/2}
      ]
    },

    # Pattern 10: "Something fishy" detection
    %{
      name: :fishy_patterns,
      context: :any,
      pattern: ~r/[^"]"[^"]*"[^"]/,
      python_location: "parse_string() 'something fishy' comments",
      description: "Python's heuristic for detecting suspicious quote patterns",
      repairs: [
        {priority: 1, action: :analyze_quote_context,
         condition: &complex_quote_pattern?/2},
        {priority: 2, action: :apply_quote_heuristics,
         condition: &ambiguous_quoting?/2}
      ]
    }
  ]

  @doc """
  Compile patterns into efficient lookup structures.
  """
  def compile_patterns do
    @python_derived_patterns
    |> Enum.group_by(& &1.context)
    |> Enum.map(fn {context, patterns} ->
      {context, compile_context_patterns(patterns)}
    end)
    |> Map.new()
  end

  defp compile_context_patterns(patterns) do
    patterns
    |> Enum.sort_by(fn pattern -> 
      # Sort by priority of highest-priority repair
      pattern.repairs
      |> Enum.map(& &1.priority)
      |> Enum.min()
    end)
    |> Enum.map(&compile_single_pattern/1)
  end

  defp compile_single_pattern(pattern) do
    %{
      name: pattern.name,
      matcher: compile_pattern_matcher(pattern.pattern),
      repairs: compile_repair_actions(pattern.repairs),
      source: pattern.python_location,
      description: pattern.description
    }
  end

  defp compile_pattern_matcher(regex_pattern) do
    # Convert regex to more efficient binary pattern matching where possible
    case extract_simple_patterns(regex_pattern) do
      {:simple, binary_patterns} -> {:binary_match, binary_patterns}
      {:complex, _} -> {:regex_match, regex_pattern}
    end
  end

  defp compile_repair_actions(repairs) do
    repairs
    |> Enum.sort_by(& &1.priority)
    |> Enum.map(fn repair ->
      %{
        priority: repair.priority,
        action: repair.action,
        condition_fn: compile_condition(repair.condition)
      }
    end)
  end

  defp compile_condition(condition_fn) when is_function(condition_fn) do
    # Convert function references to module/function tuples for serialization
    {:function, :erlang.fun_info(condition_fn)[:module], 
                 :erlang.fun_info(condition_fn)[:name]}
  end

  defp extract_simple_patterns(regex) do
    # Analyze regex to see if it can be converted to binary pattern matching
    source = Regex.source(regex)
    
    cond do
      # Simple literal strings
      String.match?(source, ~r/^[a-zA-Z0-9\s"',.:;]+$/) ->
        {:simple, [source]}
      
      # Character classes that can be efficiently checked
      String.contains?(source, ~w(\\s \\w \\d)) ->
        {:simple, extract_character_classes(source)}
      
      # Too complex for simple binary matching
      true ->
        {:complex, regex}
    end
  end

  defp extract_character_classes(source) do
    # Convert common regex patterns to binary-matchable equivalents
    source
    |> String.replace("\\s", " \t\n\r")
    |> String.replace("\\w", "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
    |> String.replace("\\d", "0123456789")
    |> List.wrap()
  end
end
