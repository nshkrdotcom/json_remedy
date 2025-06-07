# Comprehensive performance benchmark for JsonRemedy

# Load test data
test_dir = Path.join(__DIR__, "../test/support")
small_valid_json = File.read!(Path.join(test_dir, "valid.json"))
small_invalid_json = File.read!(Path.join(test_dir, "invalid.json"))
large_valid_json = File.read!(Path.join(test_dir, "large_valid.json"))
large_invalid_json = File.read!(Path.join(test_dir, "large_invalid.json"))

IO.puts("JsonRemedy Comprehensive Performance Benchmark")
IO.puts("==============================================")
IO.puts("Small valid JSON: #{byte_size(small_valid_json)} bytes")
IO.puts("Small invalid JSON: #{byte_size(small_invalid_json)} bytes")
IO.puts("Large valid JSON: #{byte_size(large_valid_json)} bytes")
IO.puts("Large invalid JSON: #{byte_size(large_invalid_json)} bytes")
IO.puts("")

# Define benchmark scenarios with different input sizes
inputs = %{
  "Small Valid (#{byte_size(small_valid_json)}B)" => small_valid_json,
  "Small Invalid (#{byte_size(small_invalid_json)}B)" => small_invalid_json,
  "Large Valid (#{byte_size(large_valid_json)}B)" => large_valid_json,
  "Large Invalid (#{byte_size(large_invalid_json)}B)" => large_invalid_json
}

scenarios = %{
  "repair_to_term" => fn json -> JsonRemedy.repair(json) end,
  "repair_to_string" => fn json -> JsonRemedy.repair_to_string(json) end,
  "repair_with_logging" => fn json -> JsonRemedy.repair(json, logging: true) end
}

# Run comprehensive benchmarks
Benchee.run(scenarios,
  inputs: inputs,
  time: 5,
  memory_time: 2,
  reduction_time: 2,
  print: [
    benchmarking: true,
    configuration: true,
    fast_warning: true
  ],
  formatters: [
    Benchee.Formatters.Console
  ]
)

# Generate performance summary
IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("PERFORMANCE SUMMARY")
IO.puts(String.duplicate("=", 60))

for {input_name, json_data} <- inputs do
  IO.puts("\n#{input_name}:")
  
  # Quick timing for each scenario
  for {scenario_name, func} <- scenarios do
    {time_us, _result} = :timer.tc(fn -> func.(json_data) end)
    throughput = 1_000_000 / time_us  # operations per second
    
    IO.puts("  #{scenario_name}: #{time_us}μs (#{Float.round(throughput, 2)} ops/s)")
  end
end

IO.puts("\nBenchmark completed successfully!")