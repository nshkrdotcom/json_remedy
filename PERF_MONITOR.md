# Simple Performance Monitor

## Usage

```bash
# 1. Set baseline (run once before optimizations)
mix run scripts/perf_monitor.exs baseline

# 2. Check current performance (run anytime)
mix run scripts/perf_monitor.exs current

# 3. Compare with baseline (run after changes)  
mix run scripts/perf_monitor.exs compare
```

## What it tracks

- **Layer 3 processing time** for 10, 25, 50, 100 objects
- **Processing rate** (KB/s)
- **Scaling behavior** (Linear vs Quadratic)
- **Improvement ratio** vs baseline

## Current baseline (O(n²) quadratic)

- 10 objects: ~5ms
- 25 objects: ~18ms  
- 50 objects: ~66ms
- 100 objects: ~291ms

## Optimization goals

- **5x improvement**: Phase 1 (IO Lists)
- **10x improvement**: Phase 2 (Binary Pattern Matching)  
- **20x improvement**: Phase 3 (Single-Pass)
- **30x improvement**: Phase 4 (Full Optimization)

**Target: 100 objects in <10ms (vs current 291ms)** 