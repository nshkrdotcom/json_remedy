# QUADRATIC PERFORMANCE ISSUE

## Problem Statement

JsonRemedy exhibits **quadratic time complexity** for non-trivial input sizes, making it unusable for real-world applications. Performance degrades catastrophically as input size increases:

- **10 objects (0.4 KB)**: 1.7ms - acceptable
- **100 objects (4.2 KB)**: 150ms - slow but usable  
- **1000 objects (44 KB)**: 15+ seconds - **UNUSABLE**

This represents a **quadratic O(n²)** complexity pattern where doubling input size quadruples processing time, rather than the expected **linear O(n)** complexity for text processing.

## Impact Assessment

### Current State
- ❌ **Unusable for production**: Any JSON > 10KB becomes prohibitively slow
- ❌ **No streaming capability**: Cannot process large files incrementally
- ❌ **Memory inefficient**: Likely creating multiple string copies
- ❌ **Blocks user experience**: 15+ second delays for moderate files

### Expected Performance
A properly optimized JSON processor should handle:
- **1MB JSON files**: < 100ms
- **10MB JSON files**: < 1 second
- **Streaming processing**: Constant memory usage regardless of file size

## Root Cause Investigation Process

### Phase 1: Performance Profiling
```bash
# 1. Create minimal reproduction case
mix run scripts/perf_repro.exs

# 2. Profile with :fprof
mix run scripts/profile_layers.exs

# 3. Memory analysis with :observer
mix run scripts/memory_analysis.exs
```

### Phase 2: Layer-by-Layer Analysis

#### Suspected Culprits (in priority order):

1. **Layer 3: Syntax Normalization** - Most Complex
   - Character-by-character parsing with state tracking
   - Multiple regex passes over the same content
   - String concatenation in loops (potential O(n²))
   - Context stack operations

2. **Layer 1: Content Cleaning** - Regex Heavy
   - Multiple regex passes
   - String replacements creating new strings
   - Potential backtracking in complex patterns

3. **Layer 2: Structural Repair** - State Machine
   - Character-by-character iteration
   - Stack operations for nesting tracking
   - String building operations

### Phase 3: Specific Investigations

#### A. String Building Analysis
```elixir
# Check if we're using inefficient string concatenation
# BAD: result = result <> new_char  # O(n²)
# GOOD: Use IO lists and IO.iodata_to_binary/1  # O(n)
```

#### B. Regex Performance
```elixir
# Profile regex operations
:timer.tc(fn -> Regex.run(pattern, large_string) end)

# Check for catastrophic backtracking
# Test with pathological inputs
```

#### C. Memory Allocation Patterns
```elixir
# Track memory growth during processing
:erlang.memory(:total) before/after each layer
```

#### D. Algorithm Complexity
```elixir
# Measure processing time vs input size
# Should be linear O(n), not quadratic O(n²)
sizes = [100, 200, 400, 800, 1600]
times = Enum.map(sizes, &measure_processing_time/1)
# Plot and analyze growth pattern
```

### Phase 4: Benchmarking Framework

Create comprehensive benchmarks:

```elixir
# scripts/comprehensive_benchmark.exs
defmodule PerformanceBenchmark do
  def run_scaling_test do
    sizes = [10, 50, 100, 500, 1000, 5000]
    
    for size <- sizes do
      input = generate_test_json(size)
      {time, _result} = :timer.tc(fn ->
        JsonRemedy.repair(input)
      end)
      
      IO.puts("Size: #{size} objects, Time: #{time}μs")
    end
  end
  
  def profile_layers(input) do
    # Profile each layer individually
    context = %{repairs: [], options: []}
    
    layers = [
      JsonRemedy.Layer1.ContentCleaning,
      JsonRemedy.Layer2.StructuralRepair,
      JsonRemedy.Layer3.SyntaxNormalization,
      JsonRemedy.Layer4.Validation
    ]
    
    for layer <- layers do
      {time, _result} = :timer.tc(fn ->
        layer.process(input, context)
      end)
      
      IO.puts("#{layer}: #{time}μs")
    end
  end
end
```

## Likely Fixes

### Immediate Optimizations

1. **Replace String Concatenation with IO Lists**
   ```elixir
   # Instead of: result = result <> char
   # Use: iolist = [iolist, char]
   # Then: IO.iodata_to_binary(iolist)
   ```

2. **Eliminate Multiple Passes**
   ```elixir
   # Instead of multiple regex operations:
   input |> fix_quotes() |> fix_commas() |> fix_booleans()
   
   # Use single-pass character processing:
   single_pass_normalization(input)
   ```

3. **Add Early Exit Conditions**
   ```elixir
   # Skip expensive processing for already-valid JSON
   case Jason.decode(input) do
     {:ok, _} -> input  # Fast path
     {:error, _} -> run_repair_pipeline(input)
   end
   ```

### Architectural Changes

1. **Streaming Architecture**
   - Process JSON in chunks
   - Maintain parsing state between chunks
   - Constant memory usage

2. **Incremental Processing**
   - Parse and validate as we repair
   - Stop processing when valid JSON is achieved
   - Layer-specific early exits

3. **Smarter Layer Selection**
   - Analyze input to determine which layers are needed
   - Skip unnecessary processing
   - Use heuristics to predict complexity

## Investigation Scripts

### scripts/perf_repro.exs
```elixir
# Minimal script to reproduce the quadratic behavior
defmodule PerfRepro do
  def run do
    sizes = [10, 100, 1000]
    
    for size <- sizes do
      json = create_malformed_json(size)
      
      {time, _} = :timer.tc(fn ->
        JsonRemedy.repair(json)
      end)
      
      rate = byte_size(json) * 1_000_000 / time / 1024  # KB/s
      
      IO.puts("Size: #{size} objects (#{Float.round(byte_size(json)/1024, 1)} KB)")
      IO.puts("Time: #{Float.round(time/1000, 1)}ms")
      IO.puts("Rate: #{Float.round(rate, 1)} KB/s")
      IO.puts("---")
    end
  end
  
  defp create_malformed_json(num_objects) do
    objects = for i <- 1..num_objects do
      ~s|{id: #{i}, name: 'Item #{i}', active: True, data: [1, 2, 3,]}|
    end
    
    "[" <> Enum.join(objects, ", ") <> "]"
  end
end

PerfRepro.run()
```

### scripts/profile_layers.exs
```elixir
# Profile individual layers to identify bottleneck
# Use :fprof for detailed function-level profiling
```

## Success Criteria

Fix is successful when:
- ✅ **Linear complexity**: O(n) processing time
- ✅ **Reasonable throughput**: > 1MB/second for malformed JSON
- ✅ **Memory efficiency**: < 2x input size memory usage
- ✅ **Large file support**: Handle 10MB+ files in < 10 seconds
- ✅ **Streaming capability**: Process arbitrarily large files

## Timeline

- **Week 1**: Investigation and profiling
- **Week 2**: Implement string building optimizations  
- **Week 3**: Single-pass processing architecture
- **Week 4**: Streaming support and final optimization

## Status

- [ ] Performance profiling completed
- [ ] Root cause identified
- [ ] Optimization strategy defined
- [ ] Implementation started
- [ ] Benchmarks passing
- [ ] Ready for production use

---

**This quadratic performance issue makes JsonRemedy unsuitable for production use and must be resolved before any real-world deployment.**
