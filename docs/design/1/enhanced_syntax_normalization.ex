defmodule JsonRemedy.Layer3.EnhancedSyntaxNormalization do
  @moduledoc """
  Enhanced Layer 3 that integrates Python's empirical knowledge while 
  preserving Elixir's architectural advantages.
  
  This module represents the "best of both worlds" approach:
  - Fast path for 90% of common cases using binary pattern matching
  - Python-derived sophisticated logic for complex edge cases
  - Maintains existing API compatibility
  - Preserves deterministic behavior and testability
  """

  @behaviour JsonRemedy.LayerBehaviour

  alias JsonRemedy.LayerBehaviour
  alias JsonRemedy.FastPathSystem
  alias JsonRemedy.ContextAwareEngine
  alias JsonRemedy.KnowledgeExtraction

  # Compile-time feature flags for optimization levels
  @enable_fast_path Application.compile_env(:json_remedy, :enable_fast_path, true)
  @enable_python_patterns Application.compile_env(:json_remedy, :enable_python_patterns, true)
  @fallback_to_original Application.compile_env(:json_remedy, :fallback_to_original, true)

  @doc """
  Enhanced process function that combines fast path with sophisticated fallbacks.
  """
  @impl LayerBehaviour
  def process(input, context) when is_binary(input) and is_map(context) do
    try do
      # Get processing strategy based on configuration and input complexity
      strategy = determine_processing_strategy(input, context)
      
      case strategy do
        :fast_path_only ->
          process_fast_path_only(input, context)
        
        :python_enhanced ->
          process_python_enhanced(input, context)
        
        :hybrid ->
          process_hybrid_approach(input, context)
        
        :original_fallback ->
          # Fall back to original Layer 3 implementation
          JsonRemedy.Layer3.SyntaxNormalization.process(input, context)
      end
    rescue
      error ->
        {:error, "Enhanced Layer 3 failed: #{inspect(error)}"}
    end
  end

  def process(nil, context), do: {:error, "Input cannot be nil"}
  def process(input, _context) when not is_binary(input) do
    {:error, "Input must be a string, got: #{inspect(input)}"}
  end
  def process(_input, context) when not is_map(context) do
    {:error, "Context must be a map, got: #{inspect(context)}"}
  end

  @impl LayerBehaviour
  def supports?(input) when is_binary(input) do
    # Enhanced detection using both original and Python-derived patterns
    original_support = JsonRemedy.Layer3.SyntaxNormalization.supports?(input)
    
    if @enable_python_patterns do
      python_patterns_detected = detect_python_patterns(input)
      original_support or python_patterns_detected
    else
      original_support
    end
  end

  def supports?(_), do: false

  @impl LayerBehaviour
  def priority(), do: 3

  @impl LayerBehaviour
  def name(), do: "Enhanced Syntax Normalization"

  @impl LayerBehaviour
  def validate_options(options) when is_list(options) do
    # Enhanced validation with new options
    base_validation = JsonRemedy.Layer3.SyntaxNormalization.validate_options(options)
    
    case base_validation do
      :ok -> validate_enhanced_options(options)
      error -> error
    end
  end

  def validate_options(_), do: {:error, "Options must be a keyword list"}

  # Processing strategies

  defp process_fast_path_only(input, context) do
    case FastPathSystem.attempt_fast_repair(input) do
      {:fast_path, repaired, repairs} ->
        updated_context = update_context_with_repairs(context, repairs, :fast_path)
        {:ok, repaired, updated_context}
      
      {:complex, input} ->
        # Fast path couldn't handle it, but we're in fast-path-only mode
        # Return minimal processing or fall back to original
        if @fallback_to_original do
          JsonRemedy.Layer3.SyntaxNormalization.process(input, context)
        else
          {:continue, input, context}
        end
    end
  end

  defp process_python_enhanced(input, context) do
    # Use full Python-derived sophisticated processing
    FastPathSystem.enhanced_syntax_normalization(input, context)
  end

  defp process_hybrid_approach(input, context) do
    # Try fast path first, fall back to Python-enhanced for complex cases
    case FastPathSystem.attempt_fast_repair(input) do
      {:fast_path, repaired, repairs} ->
        # Fast path succeeded
        updated_context = update_context_with_repairs(context, repairs, :fast_path)
        {:ok, repaired, updated_context}
      
      {:complex, input} ->
        # Fall back to Python-enhanced processing
        case FastPathSystem.enhanced_syntax_normalization(input, context) do
          {:ok, repaired, enhanced_context} ->
            # Mark that we used enhanced processing
            final_context = update_context_metadata(enhanced_context, :python_enhanced)
            {:ok, repaired, final_context}
          
          error ->
            # Final fallback to original implementation
            if @fallback_to_original do
              JsonRemedy.Layer3.SyntaxNormalization.process(input, context)
            else
              error
            end
        end
    end
  end

  # Strategy determination

  defp determine_processing_strategy(input, context) do
    # Check user preferences from context options
    user_strategy = get_in(context, [:options, :processing_strategy])
    
    case user_strategy do
      :fast_path_only -> :fast_path_only
      :python_enhanced -> :python_enhanced
      :original_only -> :original_fallback
      _ -> determine_automatic_strategy(input, context)
    end
  end

  defp determine_automatic_strategy(input, context) do
    cond do
      # Disable enhanced processing if feature flags are off
      not @enable_fast_path and not @enable_python_patterns ->
        :original_fallback
      
      # Use fast path for simple cases
      @enable_fast_path and simple_input?(input) ->
        :fast_path_only
      
      # Use Python-enhanced for complex cases
      @enable_python_patterns and complex_input?(input) ->
        :python_enhanced
      
      # Default hybrid approach
      @enable_fast_path and @enable_python_patterns ->
        :hybrid
      
      # Fallback to original
      true ->
        :original_fallback
    end
  end

  defp simple_input?(input) do
    # Heuristics for simple inputs that fast path can handle
    byte_size(input) < 1000 and
    not String.contains?(input, "\\") and
    not complex_nesting?(input) and
    not mixed_quote_styles?(input)
  end

  defp complex_input?(input) do
    # Heuristics for complex inputs that need sophisticated processing
    byte_size(input) > 5000 or
    String.contains?(input, "\\") or
    complex_nesting?(input) or
    mixed_quote_styles?(input) or
    malformed_structures?(input)
  end

  defp complex_nesting?(input) do
    # Check for deeply nested structures
    nesting_level = 0
    max_nesting = 0
    
    String.graphemes(input)
    |> Enum.reduce({nesting_level, max_nesting}, fn char, {current, max_seen} ->
      case char do
        char when char in ["{", "["] -> 
          new_level = current + 1
          {new_level, max(max_seen, new_level)}
        char when char in ["}", "]"] -> 
          {max(0, current - 1), max_seen}
        _ -> 
          {current, max_seen}
      end
    end)
    |> elem(1)
    |> Kernel.>(5)
  end

  defp mixed_quote_styles?(input) do
    String.contains?(input, "'") and String.contains?(input, "\"")
  end

  defp malformed_structures?(input) do
    # Quick detection of malformed structures
    open_braces = count_char(input, "{")
    close_braces = count_char(input, "}")
    open_brackets = count_char(input, "[")
    close_brackets = count_char(input, "]")
    
    open_braces != close_braces or
    open_brackets != close_brackets or
    String.contains?(input, ",,") or
    String.contains?(input, "::") or
    String.match?(input, ~r/[}\]],/)
  end

  defp count_char(string, char) do
    string
    |> String.graphemes()
    |> Enum.count(&(&1 == char))
  end

  # Python pattern detection

  defp detect_python_patterns(input) do
    # Check if input contains patterns that Python json_repair handles well
    python_indicators = [
      # Doubled quotes pattern
      String.contains?(input, "\"\""),
      
      # Python-style booleans/nulls
      String.contains?(input, "True") or String.contains?(input, "False") or String.contains?(input, "None"),
      
      # Unquoted keys pattern
      String.match?(input, ~r/[{,]\s*[a-zA-Z_][a-zA-Z0-9_]*\s*:/),
      
      # Single quotes
      String.contains?(input, "'"),
      
      # Missing commas pattern
      String.match?(input, ~r/"\s*"/),
      
      # Trailing commas
      String.match?(input, ~r/,\s*[}\]]/),
      
      # Complex quote patterns that Python handles well
      String.match?(input, ~r/[^"]"[^"]*"[^"]/)
    ]
    
    Enum.any?(python_indicators)
  end

  # Context and metadata management

  defp update_context_with_repairs(context, repairs, strategy) do
    all_repairs = context.repairs ++ repairs
    
    metadata = Map.get(context, :metadata, %{})
    |> Map.put(:layer3_strategy, strategy)
    |> Map.put(:layer3_enhanced, true)
    
    %{context | repairs: all_repairs, metadata: metadata}
  end

  defp update_context_metadata(context, strategy) do
    metadata = Map.get(context, :metadata, %{})
    |> Map.put(:layer3_final_strategy, strategy)
    
    %{context | metadata: metadata}
  end

  # Enhanced options validation

  defp validate_enhanced_options(options) do
    enhanced_options = [
      :processing_strategy,
      :enable_fast_path,
      :enable_python_patterns,
      :python_pattern_confidence_threshold,
      :fast_path_timeout_ms
    ]
    
    enhanced_keys = Keyword.keys(options) -- [:strict_mode, :preserve_formatting, 
                                            :normalize_quotes, :normalize_booleans, :fix_commas]
    invalid_enhanced = enhanced_keys -- enhanced_options
    
    if invalid_enhanced != [] do
      {:error, "Invalid enhanced options: #{inspect(invalid_enhanced)}"}
    else
      validate_enhanced_option_values(options)
    end
  end

  defp validate_enhanced_option_values(options) do
    Enum.reduce_while(options, :ok, fn {key, value}, _acc ->
      case validate_enhanced_option_value(key, value) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_enhanced_option_value(:processing_strategy, value) 
       when value in [:fast_path_only, :python_enhanced, :hybrid, :original_only] do
    :ok
  end

  defp validate_enhanced_option_value(:processing_strategy, value) do
    {:error, "processing_strategy must be one of [:fast_path_only, :python_enhanced, :hybrid, :original_only], got: #{inspect(value)}"}
  end

  defp validate_enhanced_option_value(key, value) 
       when key in [:enable_fast_path, :enable_python_patterns] and is_boolean(value) do
    :ok
  end

  defp validate_enhanced_option_value(:python_pattern_confidence_threshold, value) 
       when is_float(value) and value >= 0.0 and value <= 1.0 do
    :ok
  end

  defp validate_enhanced_option_value(:fast_path_timeout_ms, value) 
       when is_integer(value) and value > 0 do
    :ok
  end

  defp validate_enhanced_option_value(key, value) 
       when key in [:enable_fast_path, :enable_python_patterns] do
    {:error, "#{key} must be a boolean, got: #{inspect(value)}"}
  end

  defp validate_enhanced_option_value(:python_pattern_confidence_threshold, value) do
    {:error, "python_pattern_confidence_threshold must be a float between 0.0 and 1.0, got: #{inspect(value)}"}
  end

  defp validate_enhanced_option_value(:fast_path_timeout_ms, value) do
    {:error, "fast_path_timeout_ms must be a positive integer, got: #{inspect(value)}"}
  end

  defp validate_enhanced_option_value(_key, _value), do: :ok

  @doc """
  Public API for testing different processing strategies.
  """
  def process_with_strategy(input, context, strategy) when strategy in [:fast_path_only, :python_enhanced, :hybrid, :original_fallback] do
    enhanced_context = put_in(context, [:options, :processing_strategy], strategy)
    process(input, enhanced_context)
  end

  @doc """
  Analyze what processing strategy would be used for given input.
  """
  def analyze_strategy(input, context \\ %{repairs: [], options: [], metadata: %{}}) do
    strategy = determine_processing_strategy(input, context)
    
    %{
      strategy: strategy,
      input_complexity: analyze_input_complexity(input),
      detected_patterns: analyze_detected_patterns(input),
      feature_flags: %{
        fast_path_enabled: @enable_fast_path,
        python_patterns_enabled: @enable_python_patterns,
        fallback_enabled: @fallback_to_original
      }
    }
  end

  defp analyze_input_complexity(input) do
    %{
      size: byte_size(input),
      simple: simple_input?(input),
      complex: complex_input?(input),
      nesting_depth: calculate_max_nesting_depth(input),
      has_escapes: String.contains?(input, "\\"),
      mixed_quotes: mixed_quote_styles?(input),
      malformed_structures: malformed_structures?(input)
    }
  end

  defp analyze_detected_patterns(input) do
    if @enable_python_patterns do
      compiled_patterns = KnowledgeExtraction.compile_patterns()
      
      detected = Enum.reduce(compiled_patterns, %{}, fn {context, patterns}, acc ->
        context_matches = Enum.reduce(patterns, [], fn pattern, pattern_acc ->
          if pattern_matches_input?(input, pattern) do
            [pattern.name | pattern_acc]
          else
            pattern_acc
          end
        end)
        
        if context_matches != [] do
          Map.put(acc, context, context_matches)
        else
          acc
        end
      end)
      
      %{
        python_patterns_detected: detected,
        pattern_count: detected |> Map.values() |> List.flatten() |> length(),
        complexity_score: calculate_pattern_complexity_score(detected)
      }
    else
      %{
        python_patterns_detected: %{},
        pattern_count: 0,
        complexity_score: 0.0
      }
    end
  end

  defp calculate_max_nesting_depth(input) do
    {_, max_depth} = String.graphemes(input)
    |> Enum.reduce({0, 0}, fn char, {current_depth, max_depth} ->
      case char do
        char when char in ["{", "["] ->
          new_depth = current_depth + 1
          {new_depth, max(max_depth, new_depth)}
        char when char in ["}", "]"] ->
          {max(0, current_depth - 1), max_depth}
        _ ->
          {current_depth, max_depth}
      end
    end)
    
    max_depth
  end

  defp pattern_matches_input?(input, pattern) do
    case pattern.matcher do
      {:binary_match, binary_patterns} ->
        Enum.any?(binary_patterns, &String.contains?(input, &1))
      
      {:regex_match, regex} ->
        String.match?(input, regex)
    end
  end

  defp calculate_pattern_complexity_score(detected_patterns) do
    # Calculate complexity score based on number and types of patterns
    base_score = detected_patterns |> Map.values() |> List.flatten() |> length() |> Kernel.*(0.1)
    
    # Add complexity for certain pattern types
    complex_patterns = [:fishy_patterns, :mismatched_delimiters, :missing_closing_quotes]
    complexity_bonus = detected_patterns
    |> Map.values()
    |> List.flatten()
    |> Enum.count(&(&1 in complex_patterns))
    |> Kernel.*(0.3)
    
    min(1.0, base_score + complexity_bonus)
  end

  @doc """
  Performance benchmarking function for comparing strategies.
  """
  def benchmark_strategies(input, iterations \\ 100) do
    context = %{repairs: [], options: [], metadata: %{}}
    
    strategies = [:fast_path_only, :python_enhanced, :hybrid, :original_fallback]
    
    results = Enum.map(strategies, fn strategy ->
      {time_microseconds, result} = :timer.tc(fn ->
        Enum.map(1..iterations, fn _ ->
          process_with_strategy(input, context, strategy)
        end)
      end)
      
      avg_time = time_microseconds / iterations
      
      # Analyze result quality
      case List.last(result) do
        {:ok, output, final_context} ->
          quality_score = calculate_result_quality(input, output, final_context)
          
          %{
            strategy: strategy,
            avg_time_microseconds: avg_time,
            success: true,
            quality_score: quality_score,
            repair_count: length(final_context.repairs)
          }
        
        {:error, reason} ->
          %{
            strategy: strategy,
            avg_time_microseconds: avg_time,
            success: false,
            error: reason,
            quality_score: 0.0
          }
        
        {:continue, _, _} ->
          %{
            strategy: strategy,
            avg_time_microseconds: avg_time,
            success: false,
            error: "no repairs applied",
            quality_score: 0.0
          }
      end
    end)
    
    %{
      input_analysis: analyze_strategy(input, context),
      benchmark_results: results,
      fastest_strategy: Enum.min_by(results, &(&1[:avg_time_microseconds] || :infinity)),
      highest_quality: Enum.max_by(results, &(&1[:quality_score] || 0))
    }
  end

  defp calculate_result_quality(original_input, repaired_output, context) do
    # Calculate quality score based on multiple factors
    base_score = 0.5
    
    # Bonus for successful JSON parsing
    parse_bonus = case Jason.decode(repaired_output) do
      {:ok, _} -> 0.4
      {:error, _} -> 0.0
    end
    
    # Bonus for minimal changes (fewer repairs = higher quality if successful)
    repair_count = length(context.repairs)
    minimal_changes_bonus = if repair_count <= 3, do: 0.1, else: 0.0
    
    # Penalty for excessive length changes
    length_ratio = String.length(repaired_output) / max(1, String.length(original_input))
    length_penalty = if length_ratio > 1.5 or length_ratio < 0.5, do: -0.2, else: 0.0
    
    total_score = base_score + parse_bonus + minimal_changes_bonus + length_penalty
    max(0.0, min(1.0, total_score))
  end
end

# Configuration and feature flag management
defmodule JsonRemedy.Layer3.Config do
  @moduledoc """
  Configuration management for Enhanced Layer 3.
  
  Provides runtime configuration and feature flag management for the enhanced
  syntax normalization layer.
  """
  
  @doc """
  Get current configuration for Enhanced Layer 3.
  """
  def get_config do
    %{
      enable_fast_path: Application.get_env(:json_remedy, :enable_fast_path, true),
      enable_python_patterns: Application.get_env(:json_remedy, :enable_python_patterns, true),
      fallback_to_original: Application.get_env(:json_remedy, :fallback_to_original, true),
      default_strategy: Application.get_env(:json_remedy, :default_processing_strategy, :hybrid),
      fast_path_timeout_ms: Application.get_env(:json_remedy, :fast_path_timeout_ms, 100),
      python_pattern_confidence_threshold: Application.get_env(:json_remedy, :python_pattern_confidence_threshold, 0.7)
    }
  end
  
  @doc """
  Update configuration at runtime.
  """
  def update_config(new_config) when is_map(new_config) do
    Enum.each(new_config, fn {key, value} ->
      Application.put_env(:json_remedy, key, value)
    end)
    
    # Trigger recompilation warning if compile-time configs changed
    compile_time_keys = [:enable_fast_path, :enable_python_patterns, :fallback_to_original]
    
    if Enum.any?(compile_time_keys, &Map.has_key?(new_config, &1)) do
      IO.warn("Some configuration changes require application restart to take effect: #{inspect(compile_time_keys)}")
    end
    
    :ok
  end
  
  @doc """
  Validate configuration values.
  """
  def validate_config(config) when is_map(config) do
    validators = %{
      enable_fast_path: &is_boolean/1,
      enable_python_patterns: &is_boolean/1,
      fallback_to_original: &is_boolean/1,
      default_strategy: &(&1 in [:fast_path_only, :python_enhanced, :hybrid, :original_fallback]),
      fast_path_timeout_ms: &(is_integer(&1) and &1 > 0),
      python_pattern_confidence_threshold: &(is_float(&1) and &1 >= 0.0 and &1 <= 1.0)
    }
    
    Enum.reduce_while(config, :ok, fn {key, value}, _acc ->
      case Map.get(validators, key) do
        nil ->
          {:halt, {:error, "Unknown configuration key: #{key}"}}
        
        validator ->
          if validator.(value) do
            {:cont, :ok}
          else
            {:halt, {:error, "Invalid value for #{key}: #{inspect(value)}"}}
          end
      end
    end)
  end
  
  @doc """
  Get recommended configuration based on use case.
  """
  def recommended_config(:performance) do
    %{
      enable_fast_path: true,
      enable_python_patterns: false,
      fallback_to_original: false,
      default_strategy: :fast_path_only,
      fast_path_timeout_ms: 50
    }
  end
  
  def recommended_config(:robustness) do
    %{
      enable_fast_path: true,
      enable_python_patterns: true,
      fallback_to_original: true,
      default_strategy: :hybrid,
      python_pattern_confidence_threshold: 0.8
    }
  end
  
  def recommended_config(:compatibility) do
    %{
      enable_fast_path: false,
      enable_python_patterns: false,
      fallback_to_original: true,
      default_strategy: :original_fallback
    }
  end
end
