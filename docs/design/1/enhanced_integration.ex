defmodule JsonRemedy.EnhancedIntegration do
  @moduledoc """
  Examples and integration patterns for the enhanced JsonRemedy system.
  
  This module demonstrates how to use the enhanced Layer 3 with Python-derived
  patterns while maintaining compatibility with the existing JsonRemedy architecture.
  """

  alias JsonRemedy.Layer3.EnhancedSyntaxNormalization
  alias JsonRemedy.Layer3.Config

  @doc """
  Example 1: Basic usage with automatic strategy selection.
  
  The enhanced system automatically detects the best processing strategy
  based on input complexity and available features.
  """
  def basic_enhanced_usage do
    # Input with Python-style issues that benefit from enhanced processing
    malformed_json = ~s'''
    {
      name: 'Alice',
      active: True,
      tags: ["dev", "senior"],
      metadata: {
        created: "2024-01-01",
        updated: None
      }
    }
    '''
    
    # Use enhanced Layer 3 with default settings
    context = %{repairs: [], options: [], metadata: %{}}
    
    case EnhancedSyntaxNormalization.process(malformed_json, context) do
      {:ok, repaired, final_context} ->
        IO.puts("✅ Repaired JSON: #{repaired}")
        IO.puts("🔧 Repairs applied: #{length(final_context.repairs)}")
        IO.puts("⚡ Strategy used: #{final_context.metadata.layer3_strategy}")
        
        # Validate the result
        case Jason.decode(repaired) do
          {:ok, parsed} ->
            IO.puts("✅ Successfully parsed: #{inspect(parsed)}")
          {:error, reason} ->
            IO.puts("❌ Parse failed: #{reason}")
        end
      
      {:error, reason} ->
        IO.puts("❌ Processing failed: #{reason}")
    end
  end

  @doc """
  Example 2: Performance-optimized configuration for high-throughput scenarios.
  """
  def performance_optimized_example do
    # Configure for maximum performance
    Config.update_config(Config.recommended_config(:performance))
    
    # Batch of JSON strings to process
    json_batch = [
      ~s|{"name": 'John', age: 30}|,
      ~s|[1, 2, 3, True, False]|,
      ~s|{"active": True, "tags": ['dev', 'senior']}|,
      ~s|{"data": None, "count": 42}|
    ]
    
    # Process batch with performance monitoring
    {time_microseconds, results} = :timer.tc(fn ->
      Enum.map(json_batch, fn json ->
        context = %{
          repairs: [], 
          options: [processing_strategy: :fast_path_only], 
          metadata: %{}
        }
        
        EnhancedSyntaxNormalization.process(json, context)
      end)
    end)
    
    successful = Enum.count(results, fn
      {:ok, _, _} -> true
      _ -> false
    end)
    
    IO.puts("📊 Performance Results:")
    IO.puts("   Total time: #{time_microseconds / 1000} ms")
    IO.puts("   Average per item: #{time_microseconds / length(json_batch) / 1000} ms")
    IO.puts("   Success rate: #{successful}/#{length(json_batch)}")
    
    results
  end

  @doc """
  Example 3: Robustness-focused configuration for handling complex edge cases.
  """
  def robustness_focused_example do
    # Configure for maximum robustness
    Config.update_config(Config.recommended_config(:robustness))
    
    # Complex, problematic JSON that benefits from Python-derived patterns
    complex_json = ~s'''
    {
      "user": {
        name: "Bob O'Connor",
        "preferences": {
          theme: 'dark',
          "notifications": True,
          "settings": {
            "auto-save": True,
            backup: None,
            "features": ["advanced", 'beta-testing']
          }
        }
      },
      "metadata": {
        "created": "2024-01-01T00:00:00Z",
        updated: None,
        "version": 1.2
      }
    }
    '''
    
    context = %{
      repairs: [], 
      options: [processing_strategy: :python_enhanced], 
      metadata: %{}
    }
    
    case EnhancedSyntaxNormalization.process(complex_json, context) do
      {:ok, repaired, final_context} ->
        IO.puts("✅ Successfully processed complex JSON")
        IO.puts("🔧 Repairs applied:")
        
        Enum.each(final_context.repairs, fn repair ->
          IO.puts("   - #{repair.action} at position #{repair.position}")
        end)
        
        # Show before/after comparison
        IO.puts("\n📝 Before:")
        IO.puts(String.slice(complex_json, 0, 200) <> "...")
        
        IO.puts("\n📝 After:")
        IO.puts(String.slice(repaired, 0, 200) <> "...")
        
        {:ok, repaired, final_context}
      
      error ->
        IO.puts("❌ Failed to process complex JSON: #{inspect(error)}")
        error
    end
  end

  @doc """
  Example 4: Strategy comparison and benchmarking.
  """
  def strategy_comparison_example do
    test_json = ~s|{name: 'Alice', active: True, tags: ["dev", "senior"], count: None}|
    
    IO.puts("🔍 Analyzing input complexity...")
    analysis = EnhancedSyntaxNormalization.analyze_strategy(test_json)
    
    IO.puts("Input Analysis:")
    IO.puts("  Strategy: #{analysis.strategy}")
    IO.puts("  Size: #{analysis.input_complexity.size} bytes")
    IO.puts("  Complex: #{analysis.input_complexity.complex}")
    IO.puts("  Pattern count: #{analysis.detected_patterns.pattern_count}")
    
    IO.puts("\n🏁 Running benchmark...")
    benchmark_results = EnhancedSyntaxNormalization.benchmark_strategies(test_json, 50)
    
    IO.puts("\nBenchmark Results:")
    Enum.each(benchmark_results.benchmark_results, fn result ->
      status = if result.success, do: "✅", else: "❌"
      IO.puts("  #{status} #{result.strategy}: #{Float.round(result.avg_time_microseconds, 1)}μs (quality: #{Float.round(result[:quality_score] || 0, 2)})")
    end)
    
    fastest = benchmark_results.fastest_strategy
    highest_quality = benchmark_results.highest_quality
    
    IO.puts("\n🏆 Winner Analysis:")
    IO.puts("  Fastest: #{fastest.strategy} (#{Float.round(fastest.avg_time_microseconds, 1)}μs)")
    IO.puts("  Highest Quality: #{highest_quality.strategy} (score: #{Float.round(highest_quality.quality_score, 2)})")
    
    benchmark_results
  end

  @doc """
  Example 5: Custom pattern integration.
  
  Shows how to extend the system with domain-specific patterns.
  """
  def custom_pattern_example do
    # Define custom patterns for domain-specific JSON repair
    custom_patterns = [
      # API-specific pattern: fix timestamp format
      %{
        name: :fix_timestamp_format,
        context: :object_value,
        pattern: ~r/(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/,
        repairs: [
          {priority: 1, action: :add_timezone_suffix, condition: &missing_timezone?/2}
        ]
      },
      
      # Business logic pattern: normalize status values
      %{
        name: :normalize_status,
        context: :object_value,
        pattern: ~r/"(active|inactive|pending)"/i,
        repairs: [
          {priority: 1, action: :lowercase_status, condition: &is_status_field?/2}
        ]
      }
    ]
    
    # This would integrate with the KnowledgeExtraction system
    IO.puts("🔧 Custom patterns defined:")
    Enum.each(custom_patterns, fn pattern ->
      IO.puts("  - #{pattern.name}: #{pattern.pattern.source}")
    end)
    
    # Example usage with custom patterns would require extending the
    # KnowledgeExtraction module to accept runtime pattern registration
    custom_patterns
  end

  @doc """
  Example 6: Integration with existing JsonRemedy pipeline.
  """
  def full_pipeline_integration_example do
    # Complex input that requires multiple layers
    malformed_input = ~s'''
    ```json
    // This is a configuration file
    {
      /* User settings */
      name: 'Alice',
      "age": 30,
      active: True,
      preferences: {
        theme: "dark",
        notifications: True,
        tags: ["dev", "senior",]
      },
      metadata: {
        created: None,
        updated: "2024-01-01"
      }
    ```
    '''
    
    IO.puts("🔄 Processing through full pipeline...")
    
    # Layer 1: Content Cleaning
    context1 = %{repairs: [], options: [], metadata: %{}}
    
    case JsonRemedy.Layer1.ContentCleaning.process(malformed_input, context1) do
      {:ok, cleaned, context2} ->
        IO.puts("✅ Layer 1 complete: Code fences removed")
        
        # Layer 2: Structural Repair
        case JsonRemedy.Layer2.StructuralRepair.process(cleaned, context2) do
          {:ok, structured, context3} ->
            IO.puts("✅ Layer 2 complete: Structure validated")
            
            # Layer 3: Enhanced Syntax Normalization
            case EnhancedSyntaxNormalization.process(structured, context3) do
              {:ok, normalized, context4} ->
                IO.puts("✅ Layer 3 complete: Syntax normalized")
                
                # Layer 4: Validation
                case JsonRemedy.Layer4.Validation.process(normalized, context4) do
                  {:ok, parsed, final_context} ->
                    IO.puts("✅ Layer 4 complete: JSON validated and parsed")
                    IO.puts("\n📊 Final Results:")
                    IO.puts("  Total repairs: #{length(final_context.repairs)}")
                    IO.puts("  Strategy used: #{final_context.metadata[:layer3_strategy]}")
                    IO.puts("  Parsed successfully: #{is_map(parsed) or is_list(parsed)}")
                    
                    # Show repair summary
                    repair_summary = final_context.repairs
                    |> Enum.group_by(& &1.layer)
                    |> Enum.map(fn {layer, repairs} -> 
                         {layer, length(repairs)} 
                       end)
                    
                    IO.puts("  Repairs by layer: #{inspect(repair_summary)}")
                    
                    {:ok, parsed, final_context}
                  
                  error ->
                    IO.puts("❌ Layer 4 failed: #{inspect(error)}")
                    error
                end
              
              error ->
                IO.puts("❌ Layer 3 failed: #{inspect(error)}")
                error
            end
          
          error ->
            IO.puts("❌ Layer 2 failed: #{inspect(error)}")
            error
        end
      
      error ->
        IO.puts("❌ Layer 1 failed: #{inspect(error)}")
        error
    end
  end

  @doc """
  Example 7: Runtime configuration and feature toggle.
  """
  def runtime_configuration_example do
    IO.puts("🛠️  Current configuration:")
    current_config = Config.get_config()
    Enum.each(current_config, fn {key, value} ->
      IO.puts("  #{key}: #{inspect(value)}")
    end)
    
    # Test with different configurations
    test_cases = [
      {"Performance mode", Config.recommended_config(:performance)},
      {"Robustness mode", Config.recommended_config(:robustness)},
      {"Compatibility mode", Config.recommended_config(:compatibility)}
    ]
    
    test_json = ~s|{name: 'Test', active: True, value: None}|
    
    results = Enum.map(test_cases, fn {name, config} ->
      IO.puts("\n🔧 Testing #{name}...")
      Config.update_config(config)
      
      context = %{repairs: [], options: [], metadata: %{}}
      
      {time, result} = :timer.tc(fn ->
        EnhancedSyntaxNormalization.process(test_json, context)
      end)
      
      case result do
        {:ok, _, final_context} ->
          IO.puts("  ✅ Success in #{time / 1000}ms, #{length(final_context.repairs)} repairs")
          IO.puts("  Strategy: #{final_context.metadata[:layer3_strategy]}")
          
        error ->
          IO.puts("  ❌ Failed: #{inspect(error)}")
      end
      
      {name, config, time, result}
    end)
    
    # Restore original configuration
    Config.update_config(current_config)
    
    results
  end

  # Helper functions for custom patterns
  defp missing_timezone?(input, context) do
    # Check if timestamp is missing timezone info
    # Implementation would analyze the matched timestamp
    true  # Simplified
  end

  defp is_status_field?(input, context) do
    # Check if we're in a field that should contain status values
    # Implementation would check the surrounding context
    true  # Simplified
  end
end

# Usage examples that can be run in IEx
defmodule JsonRemedy.Examples.Runner do
  @moduledoc """
  Runner module for executing the examples in an IEx session.
  """
  
  alias JsonRemedy.EnhancedIntegration
  
  def run_all_examples do
    IO.puts("🚀 Running JsonRemedy Enhanced Integration Examples\n")
    
    examples = [
      {"Basic Enhanced Usage", &EnhancedIntegration.basic_enhanced_usage/0},
      {"Performance Optimized", &EnhancedIntegration.performance_optimized_example/0},
      {"Robustness Focused", &EnhancedIntegration.robustness_focused_example/0},
      {"Strategy Comparison", &EnhancedIntegration.strategy_comparison_example/0},
      {"Custom Patterns", &EnhancedIntegration.custom_pattern_example/0},
      {"Full Pipeline Integration", &EnhancedIntegration.full_pipeline_integration_example/0},
      {"Runtime Configuration", &EnhancedIntegration.runtime_configuration_example/0}
    ]
    
    results = Enum.map(examples, fn {name, example_fn} ->
      IO.puts("=" <> String.duplicate("=", String.length(name) + 2))
      IO.puts(" #{name}")
      IO.puts("=" <> String.duplicate("=", String.length(name) + 2))
      
      try do
        result = example_fn.()
        IO.puts("✅ Example completed successfully\n")
        {name, :success, result}
      rescue
        error ->
          IO.puts("❌ Example failed: #{inspect(error)}\n")
          {name, :error, error}
      end
    end)
    
    # Summary
    IO.puts("📊 Example Summary:")
    successful = Enum.count(results, fn {_, status, _} -> status == :success end)
    total = length(results)
    IO.puts("  Successful: #{successful}/#{total}")
    
    if successful < total do
      IO.puts("  Failed examples:")
      Enum.each(results, fn {name, status, _} ->
        if status == :error do
          IO.puts("    - #{name}")
        end
      end)
    end
    
    results
  end
  
  def run_example(example_name) when is_atom(example_name) do
    case example_name do
      :basic -> EnhancedIntegration.basic_enhanced_usage()
      :performance -> EnhancedIntegration.performance_optimized_example()
      :robustness -> EnhancedIntegration.robustness_focused_example()
      :comparison -> EnhancedIntegration.strategy_comparison_example()
      :custom -> EnhancedIntegration.custom_pattern_example()
      :pipeline -> EnhancedIntegration.full_pipeline_integration_example()
      :config -> EnhancedIntegration.runtime_configuration_example()
      _ -> {:error, "Unknown example: #{example_name}"}
    end
  end
end
