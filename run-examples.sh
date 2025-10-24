#!/bin/bash
# Run all JsonRemedy example scripts
# This script executes each example file in the examples/ directory
# and shows the output

echo "=================================="
echo "JsonRemedy Examples Runner"
echo "=================================="
echo ""

# Counter for tracking
total=0
passed=0
failed=0

# Array of example files (all .exs files in examples/)
examples=(
  "examples/basic_usage.exs"
  "examples/hardcoded_patterns_examples.exs"
  "examples/html_content_examples.exs"
  "examples/performance_benchmarks.exs"
  "examples/quick_performance.exs"
  "examples/real_world_scenarios.exs"
  "examples/repair_example.exs"
  "examples/simple_stress_test.exs"
)

# Run each example
for example in "${examples[@]}"; do
  total=$((total + 1))
  filename=$(basename "$example")

  echo ""
  echo "=================================="
  echo "[$total] Running: $filename"
  echo "=================================="
  echo ""

  if mix run "$example" 2>&1; then
    echo ""
    echo "✓ PASSED: $filename"
    passed=$((passed + 1))
  else
    echo ""
    echo "✗ FAILED: $filename"
    failed=$((failed + 1))
  fi

  echo ""
done

# Summary
echo ""
echo "=================================="
echo "Summary"
echo "=================================="
echo "Total:  $total examples"
echo "Passed: $passed"
echo "Failed: $failed"
echo ""

if [ $failed -eq 0 ]; then
  echo "✓ All examples passed!"
  exit 0
else
  echo "✗ Some examples failed."
  exit 1
fi
