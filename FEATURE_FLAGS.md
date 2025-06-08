# Feature Flags - JsonRemedy Performance Optimization System

This document explains the feature flag system used in JsonRemedy to enable progressive performance optimizations while maintaining stability and compatibility.

## Overview

JsonRemedy uses a sophisticated feature flag system to control performance optimizations at runtime. This system allows users to select the best performance profile for their use case while providing fallback options for compatibility and debugging.

## Why Feature Flags for Performance?

### 1. **Progressive Optimization Strategy**
Instead of implementing a single optimization approach, JsonRemedy offers multiple optimization levels that can be selected based on:
- **Performance requirements** - Critical vs non-critical paths
- **Compatibility needs** - Legacy system support
- **Debugging requirements** - Easier troubleshooting with simpler implementations
- **Memory constraints** - Different memory/speed tradeoffs

### 2. **Risk Mitigation**
Performance optimizations often involve:
- Complex algorithms that may have edge cases
- Platform-specific optimizations that may not work everywhere
- Memory vs speed tradeoffs that may not suit all environments

Feature flags allow users to **fall back to proven implementations** if optimizations cause issues.

### 3. **Benchmarking and Validation**
Feature flags enable:
- **A/B testing** of different optimization approaches
- **Performance regression detection** by comparing implementations
- **Gradual rollout** of new optimizations

## Layer 3 Syntax Normalization Feature Flags

### Primary Optimization Phase Selection

```elixir
# In config/config.exs or Application.put_env/3
config :json_remedy, :layer3_optimization_phase, 2
```

**Available Phases:**

#### **Phase 0: Original Implementation** (`optimization_phase: 0`)
```elixir
config :json_remedy, :layer3_optimization_phase, 0
```

**When to use:**
- **Debugging complex parsing issues** - Simplest implementation, easiest to understand
- **Maximum compatibility** - Most conservative approach
- **Legacy system support** - Proven stable implementation

**Performance:** Baseline performance using string concatenation and character-by-character processing.

**Trade-offs:**
- ✅ Maximum stability and compatibility
- ✅ Easiest to debug and understand
- ❌ Slowest performance (O(n²) string operations)

#### **Phase 1: IO List Optimization** (`optimization_phase: 1`)  
```elixir
config :json_remedy, :layer3_optimization_phase, 1
```

**When to use:**
- **Moderate performance improvement needed** - 2-3x faster than original
- **Memory-constrained environments** - Better memory efficiency
- **Large JSON processing** - Eliminates O(n²) string concatenation bottleneck

**Performance:** Eliminates O(n²) string concatenation by using IO lists for O(1) append operations.

**Trade-offs:**
- ✅ Significant performance improvement (2-3x faster)
- ✅ Better memory efficiency
- ✅ Still relatively simple algorithm
- ❌ More complex than original implementation

#### **Phase 2: Binary Pattern Matching** (`optimization_phase: 2`) **[DEFAULT]**
```elixir
config :json_remedy, :layer3_optimization_phase, 2  # Default
```

**When to use:**
- **Maximum performance required** - 5-10x faster than original
- **High-throughput JSON processing** - Eliminates String.at/2 calls
- **Production environments** - Best overall performance

**Performance:** Eliminates String.at/2 function calls by using binary pattern matching for maximum speed.

**Trade-offs:**
- ✅ Maximum performance (5-10x faster than original)
- ✅ Most efficient memory usage
- ✅ Leverages Erlang VM's binary optimization
- ❌ Most complex implementation
- ❌ Harder to debug if issues arise

### Secondary IO List Optimization

```elixir
# Controls sub-optimization within key quoting functions
config :json_remedy, :layer3_iolist_optimization, true  # Default: true
```

**Purpose:** Controls whether key quoting functions use IO list optimization even when not in Phase 1.

**When to disable (`false`):**
- **Debugging key quoting issues** - Simpler string-based implementation
- **Memory debugging** - Eliminate IO list complexity
- **Platform compatibility issues** - Some platforms may have IO list issues

## Configuration Examples

### Development Environment
```elixir
# config/dev.exs
config :json_remedy,
  layer3_optimization_phase: 0,  # Use original for easier debugging
  layer3_iolist_optimization: false
```

### Testing Environment  
```elixir
# config/test.exs  
config :json_remedy,
  layer3_optimization_phase: 2,  # Test with maximum optimization
  layer3_iolist_optimization: true
```

### Production Environment
```elixir
# config/prod.exs
config :json_remedy,
  layer3_optimization_phase: 2,  # Maximum performance
  layer3_iolist_optimization: true
```

### Compatibility/Fallback Mode
```elixir
# For maximum compatibility when issues arise
config :json_remedy,
  layer3_optimization_phase: 0,  # Most stable implementation  
  layer3_iolist_optimization: false
```

## Runtime Configuration

Feature flags can also be set at runtime:

```elixir
# Temporarily switch to compatibility mode
Application.put_env(:json_remedy, :layer3_optimization_phase, 0)

# Process some problematic JSON
{:ok, result} = JsonRemedy.process(problematic_json)

# Switch back to optimized mode
Application.put_env(:json_remedy, :layer3_optimization_phase, 2)
```

## Performance Benchmarks

Based on internal testing with various JSON sizes:

| Phase | Implementation | Speed vs Original | Memory Usage | Complexity |
|-------|---------------|------------------|--------------|------------|
| 0 | Original | 1x (baseline) | High | Low |
| 1 | IO Lists | 2-3x faster | Medium | Medium |
| 2 | Binary Matching | 5-10x faster | Low | High |

**Test conditions:** 1MB malformed JSON with mixed syntax issues on Erlang/OTP 25+

## Troubleshooting with Feature Flags

### Performance Issues
1. **Start with Phase 0** to establish baseline
2. **Test Phase 1** to isolate IO list optimizations  
3. **Enable Phase 2** only after confirming Phase 1 works

### Memory Issues
1. **Disable IO list optimization** first: `layer3_iolist_optimization: false`
2. **Use Phase 0** if memory issues persist
3. **Monitor memory usage** with `:observer.start()`

### Parsing Errors
1. **Switch to Phase 0** to eliminate optimization-related issues
2. **Compare results** between phases to isolate the problem
3. **Report issues** with specific phase and configuration details

## Implementation Architecture

The feature flag system preserves the **single-pass optimization principle** that prevents catastrophic performance regressions:

```elixir
# In JsonRemedy.Layer3.SyntaxNormalization
defp normalize_syntax(content) do
  case Application.get_env(:json_remedy, :layer3_optimization_phase, 2) do
    2 -> normalize_syntax_binary_optimized(content)    # Binary optimization
    1 -> normalize_syntax_iolist(content)             # IO list optimization  
    _ -> normalize_syntax_original(content)           # Original implementation
  end
end
```

**Key principle:** All phases maintain **integrated single-pass processing**. The feature flags select between different **implementations** of the same algorithm, not between single-pass vs multi-pass approaches.

## Best Practices

### 1. **Development Workflow**
- **Start with Phase 0** during development for easier debugging
- **Test with Phase 2** before deployment to catch optimization-specific issues
- **Use Phase 1** as middle ground when Phase 2 causes issues

### 2. **Production Deployment**
- **Always benchmark** your specific JSON patterns with different phases
- **Monitor performance** after enabling optimizations
- **Have fallback plan** ready if issues arise

### 3. **Debugging Strategy**
- **Use Phase 0** to isolate parsing logic issues from optimization issues
- **Compare outputs** between phases to verify correctness
- **Enable optimizations incrementally** (0 → 1 → 2)

### 4. **Performance Testing**
- **Benchmark with realistic data** - your actual JSON patterns
- **Test with various sizes** - optimizations may have different curves
- **Monitor memory usage** - especially with large JSON files

## Future Extensibility

The feature flag system is designed for extensibility:

```elixir
# Future: Phase 3 could add SIMD optimizations
config :json_remedy, :layer3_optimization_phase, 3

# Future: Platform-specific optimizations  
config :json_remedy, :layer3_platform_optimization, :native_code

# Future: Memory vs speed profiles
config :json_remedy, :layer3_performance_profile, :memory_optimized
```

This architecture allows JsonRemedy to evolve its performance optimizations while maintaining backward compatibility and providing users with fine-grained control over performance characteristics.