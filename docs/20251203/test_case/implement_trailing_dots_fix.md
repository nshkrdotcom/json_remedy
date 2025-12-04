# Task: Handle Gemini Max Tokens Trailing Dots Truncation

## Context

See `gemini_max_tokens_trailing_dots.md` in this directory for a real-world test case where Gemini API hits `max_output_tokens` and fills the remaining output with dots (`...`) instead of completing the JSON.

The JSON is cut off mid-object like:
```json
{
  "excerpt": "-  Weight loss.......................................................................................
```

And continues with 14,192 dots until the response ends.

## Requirements

1. **Create a test case** in the test suite based on the truncated JSON in `gemini_max_tokens_trailing_dots.md`

2. **Enhance JsonRemedy** to detect and handle this pattern:
   - Detect trailing dots (`.{3,}` at end of string)
   - Strip trailing dots
   - Attempt to repair the truncated JSON (close open strings, arrays, objects)
   - Return the repaired JSON with as much valid data as possible

3. **Create a working example** demonstrating the fix

4. **Bump version** in `mix.exs` (increment patch version x.y.z -> x.y.(z+1))

5. **Update CHANGELOG.md** with entry for the new version dated 2025-12-03:
   - Describe the new trailing dots truncation handling feature

6. **Update README.md** if needed to document this capability

7. **Update any other docs** as needed

## Success Criteria

- [ ] No compilation warnings
- [ ] All tests pass (`mix test`)
- [ ] Dialyzer passes (`mix dialyzer`)
- [ ] Credo clean (`mix credo --strict`)

## Implementation Notes

- The dots appear when Gemini hits token limits during structured output
- The truncation can happen mid-string, mid-array, or mid-object
- Priority is recovering as much valid data as possible
- The `citations` array in the test case is incomplete - we want to preserve the citations that ARE complete
