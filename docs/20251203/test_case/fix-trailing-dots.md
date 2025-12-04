Read the test case at docs/20251203/test_case/gemini_max_tokens_trailing_dots.md - this is real broken JSON from Gemini API when it hits max_output_tokens and fills the rest with dots.

Tasks:
1. Create a test case in the test suite for this trailing dots truncation pattern
2. Devise a plan to enhance JsonRemedy to handle this (strip trailing dots, repair truncated JSON)
3. Implement the fix with a working example
4. Bump mix.exs version x.y.z -> x.y.(z+1)
5. Add CHANGELOG.md entry for the new version dated 2025-12-03
6. Update README.md to document this capability
7. Update other docs as needed

Success criteria - ALL must pass:
- mix compile --warnings-as-errors
- mix test
- mix dialyzer
- mix credo --strict

Do not stop until all criteria pass.
