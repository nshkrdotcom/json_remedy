# Simple performance validation test
# Run with: mix run bench/simple_perf_test.exs

IO.puts("JsonRemedy Performance Validation")
IO.puts("==================================")

# Test cases
test_json = ~s|{name: "Alice", age: 30, active: True, scores: [95, 87, 92,]|
complex_json = File.read!("test/support/large_invalid.json")

# Performance test function
test_performance = fn name, json ->
  # Warmup
  for _ <- 1..5, do: JsonRemedy.repair(json)
  
  # Time 10 runs
  times = for _ <- 1..10 do
    {time, _result} = :timer.tc(fn -> JsonRemedy.repair(json) end)
    time
  end
  
  avg_time = Enum.sum(times) / length(times)
  ops_per_sec = 1_000_000 / avg_time
  
  IO.puts("#{name}: #{Float.round(avg_time, 1)}μs avg | #{Float.round(ops_per_sec, 0)} ops/sec")
  {avg_time, ops_per_sec}
end

# Run tests
{_simple_time, simple_ops} = test_performance.("Simple malformed JSON", test_json)
{_complex_time, complex_ops} = test_performance.("Complex malformed JSON", complex_json)

IO.puts("\nPerformance Summary:")
IO.puts("✅ Simple JSON: #{Float.round(simple_ops, 0)} operations/second")
IO.puts("✅ Complex JSON: #{Float.round(complex_ops, 0)} operations/second")

# Validate against thresholds
if simple_ops > 30_000 do
  IO.puts("✅ PASS: Simple JSON performance exceeds 30K ops/sec")
else
  IO.puts("❌ FAIL: Simple JSON performance below threshold")
end

if complex_ops > 1_000 do
  IO.puts("✅ PASS: Complex JSON performance exceeds 1K ops/sec")
else
  IO.puts("❌ FAIL: Complex JSON performance below threshold")
end

IO.puts("\nPerformance validation complete!")