# Performance benchmark for JsonRemedy
# Replicates the Python performance tests to compare equivalent functionality

# Load test data
test_dir = Path.join(__DIR__, "../test/support")
valid_json = File.read!(Path.join(test_dir, "valid.json"))
invalid_json = File.read!(Path.join(test_dir, "invalid.json"))

IO.puts("JsonRemedy Performance Benchmark")
IO.puts("=================================")
IO.puts("Valid JSON size: #{byte_size(valid_json)} bytes")
IO.puts("Invalid JSON size: #{byte_size(invalid_json)} bytes")
IO.puts("")

# Define benchmark scenarios
scenarios = %{
  # Equivalent to Python's return_objects=True, skip_json_loads=True
  # (repair and return Elixir terms, don't re-encode to JSON)
  "repair_to_term_valid" => fn -> JsonRemedy.repair(valid_json) end,
  "repair_to_term_invalid" => fn -> JsonRemedy.repair(invalid_json) end,
  
  # Equivalent to Python's return_objects=True, skip_json_loads=False  
  # (repair and return Elixir terms, with JSON validation)
  "repair_with_validation_valid" => fn -> 
    case JsonRemedy.repair(valid_json) do
      {:ok, result} -> Jason.decode!(Jason.encode!(result))
      error -> error
    end
  end,
  "repair_with_validation_invalid" => fn -> 
    case JsonRemedy.repair(invalid_json) do
      {:ok, result} -> Jason.decode!(Jason.encode!(result))
      error -> error
    end
  end,
  
  # Equivalent to Python's return_objects=False, skip_json_loads=True
  # (repair and return JSON string, don't validate)
  "repair_to_string_valid" => fn -> JsonRemedy.repair_to_string(valid_json) end,
  "repair_to_string_invalid" => fn -> JsonRemedy.repair_to_string(invalid_json) end,
  
  # Equivalent to Python's return_objects=False, skip_json_loads=False
  # (repair, return JSON string, and validate)
  "repair_and_validate_valid" => fn -> 
    case JsonRemedy.repair_to_string(valid_json) do
      {:ok, json_string} -> Jason.decode!(json_string)
      error -> error
    end
  end,
  "repair_and_validate_invalid" => fn -> 
    case JsonRemedy.repair_to_string(invalid_json) do
      {:ok, json_string} -> Jason.decode!(json_string)
      error -> error
    end
  end,
}

# Run benchmarks
Benchee.run(scenarios,
  time: 3,
  memory_time: 1,
  reduction_time: 1,
  print: [
    benchmarking: true,
    configuration: true,
    fast_warning: true
  ],
  formatters: [
    Benchee.Formatters.Console
  ]
)

# Performance thresholds (converted from Python test expectations)
thresholds = %{
  "repair_to_term_valid" => 3_000,      # 3ms in microseconds
  "repair_to_term_invalid" => 3_000,    # 3ms
  "repair_with_validation_valid" => 30, # 30μs  
  "repair_with_validation_invalid" => 3_000, # 3ms
  "repair_to_string_valid" => 3_000,    # 3ms
  "repair_to_string_invalid" => 3_000,  # 3ms
  "repair_and_validate_valid" => 60,    # 60μs
  "repair_and_validate_invalid" => 3_000 # 3ms
}

IO.puts("\nPerformance Threshold Analysis")
IO.puts("==============================")

# Quick performance validation
for {name, func} <- scenarios do
  threshold = thresholds[name]
  
  # Run a quick timing test
  {time_us, _result} = :timer.tc(func)
  
  status = if time_us <= threshold, do: "✅ PASS", else: "❌ FAIL"
  
  IO.puts("#{name}: #{time_us}μs (threshold: #{threshold}μs) #{status}")
end

IO.puts("\nBenchmark complete!")