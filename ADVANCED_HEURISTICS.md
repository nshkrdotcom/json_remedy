# Advanced Heuristics and Contextual Understanding in JsonRemedy

Building upon the probabilistic repair model, this document explores advanced heuristics and enhancements to contextual understanding. These ideas aim to further refine JsonRemedy's ability to make intelligent repair decisions, leading to more accurate and semantically correct JSON outputs.

## Enriching `JsonContext` for Deeper Understanding

The `JsonContext` is pivotal for nuanced repairs. Beyond the previously suggested `last_significant_char`, `last_token_type`, and `lookahead_buffer`, we can incorporate more sophisticated tracking:

1.  **N-gram Token History**:
    *   Instead of just the `last_token_type`, maintain a short history (e.g., the last 2-3 tokens). `[:key, :colon, :string_value]` provides much more context than just `:string_value`.
    *   This can help differentiate ambiguous situations. For example, a standalone number might be part of a list `[1, 2, 3]` or an error `{"key": 1 2}`. Token history can help assign costs.

2.  **Structural Depth and Type Stack**:
    *   Maintain the current nesting `depth`.
    *   Keep a `type_stack` (e.g., `[:object, :array, :object]`). This is more robust than just `current_type`.
    *   This helps in validating structural integrity and applying repairs that are sensitive to nesting levels (e.g., maximum depth constraints, typical array/object patterns).

3.  **Key Duplication Tracking**:
    *   Within an object context, keep a set of keys already encountered at the current nesting level.
    *   This allows the system to assign a higher cost to repairs that would result in duplicate keys, or to automatically rename a duplicate key (e.g., `key_1`, `key_2`) with an associated cost.

4.  **Value Type Affinity**:
    *   For arrays, observe the types of initial elements. If an array starts with `[1, 2, "abc", 3]`, the string `"abc"` might be an error. A heuristic could assign a cost to type inconsistencies within an array.
    *   Similarly, if a key `age` consistently has integer values, encountering `{"age": "forty"}` might trigger a higher cost for keeping it as a string versus attempting a conversion or flagging. This borders on semantic understanding.

5.  **Whitespace and Comment Significance**:
    *   Track if significant whitespace (e.g., multiple newlines) or comments separate tokens. This can sometimes indicate intended separation or grouping that typical JSON parsers ignore but might be relevant for repair heuristics.
    *   *Example*: `{"key1": "value1"}

 {"key2": "value2"}` is more likely two objects needing to be wrapped in an array than `{"key1": "value1"}{"key2": "value2"}`.

## Advanced Heuristics for the Declarative Rule Set

The declarative rule set within `Layer3.SyntaxNormalization` (and potentially other layers) can be expanded with more sophisticated rules:

1.  **Context-Sensitive Auto-Correction of Common Typos**:
    *   **Rule**: If an unquoted literal like `flase`, `ture`, `nill`, `Nnoe` appears in a value context.
    *   **Repair**: Correct to `false`, `true`, `null`.
    *   **Cost**: Low.
    *   **Context**: `JsonContext` indicates it's a value position.

2.  **Intelligent Missing Comma/Colon Insertion**:
    *   **Rule**: If `JsonContext.last_token_type` is `:string_value` and the next token is `:string_literal` (unquoted) in an object key context.
    *   **Repair A**: Insert comma (treat as `value, new_key`). Cost: Medium.
    *   **Repair B**: Insert colon (treat as `{"original_value_as_key": new_key}`). Cost: High.
    *   The enriched context (N-gram token history) helps decide. If `last_tokens` were `[:key, :colon, :string_value]`, Repair A is more likely.

3.  **Handling of Concatenated JSON in Strings**:
    *   **Rule**: A string value itself contains what appears to be a complete JSON object or array (e.g., `"{"inner_key": "inner_value"}"`).
    *   **Repair A**: Keep as an escaped string (default). Cost: Low.
    *   **Repair B**: Unescape and parse it as a nested structure. Cost: Medium-High (as it changes semantics).
    *   **Condition**: This could be triggered by a user option or if the outer JSON structure is otherwise trivial (e.g., just one key-value pair).

4.  **Heuristics for Truncated Structures**:
    *   **Rule**: Input ends abruptly while `JsonContext.type_stack` is not empty (e.g., `{"key": ["value1",` ).
    *   **Repair**: Add appropriate closing delimiters (`]` and `}`).
    *   **Cost**: Medium, increases with the number of delimiters to add.
    *   **Refinement**: If `lookahead_buffer` (if reading from a stream) suggests more data might come, cost of closing could be higher, or it might generate a "wait/retry" candidate.

5.  **Repairing Numeric Value Errors**:
    *   **Rule**: A number contains multiple decimal points (`1.2.3`) or misplaced commas (`1,234.56` not as thousands separators in some locales).
    *   **Repair A**: Treat as string. Cost: Medium.
    *   **Repair B**: Attempt to fix based on common patterns (e.g., keep first decimal, remove others). Cost: Medium-High.
    *   **Repair C (for `1,234.56`):** If a "locale" or "number style" option is active, parse by removing group separators. Cost: Low-Medium.

6.  **Semantic Heuristics (More Experimental)**:
    *   **Rule**: Key name suggests a type (e.g., `isActive`, `count`, `nameList`).
    *   **Context**: `JsonContext` includes a (possibly configurable) dictionary of common key names and their expected value types (e.g., `isActive: boolean`, `count: number`, `nameList: array`).
    *   **Repair**: If the actual value type mismatches, assign a higher cost to keeping it as is versus attempting a conversion or flagging.
    *   *Example*: `{"isActive": "True_String"}`. Cost to keep as string is higher if `isActive` is known to expect boolean. Cost to convert "True_String" to `true` (if possible) is lower.
    *   This is complex as it borders on schema validation/inference.

7.  **Balancing Repairs for Unmatched Delimiters**:
    *   **Rule**: An unmatched closing delimiter (e.g., `}`) is found.
    *   **Context**: `JsonContext.type_stack` shows the current open structure (e.g., `[:object, :array]`).
    *   **Repair A**: Delete the unmatched delimiter. Cost: Medium.
    *   **Repair B**: Insert corresponding opening delimiter(s) earlier in the text (if a plausible point can be found). Cost: High.
    *   The beam search would explore both. If deleting the `}` leads to a valid parse with lower cost, it's preferred. If inserting `{[` earlier resolves more issues, that path might win.

## Dynamic Heuristic Adjustment

-   **Feedback Loop**: If the `Validation` layer (Layer 4) frequently rejects candidates derived from a specific heuristic, the cost associated with that heuristic could be dynamically (or manually) increased.
-   **Source-Specific Profiles**: If JsonRemedy often processes data from a known source with idiosyncratic error patterns, users could define profiles that adjust costs for certain rules or enable source-specific heuristics.

By combining a richer understanding of the JSON's context with a flexible set of advanced heuristics (each with a well-considered cost), JsonRemedy can significantly improve its ability to not just fix syntax but to infer the most probable *intended* structure of malformed JSON.
