# Innovations in JSON Repair for JsonRemedy

This document outlines foundational innovative ideas for advancing the capabilities of the JsonRemedy library, drawing inspiration from the concepts detailed in `docs/design/1.md`. These ideas aim to elevate JsonRemedy to a world-class JSON repair tool by moving beyond deterministic fixes to a more intelligent, adaptable, and robust system.

## Core Concepts for Next-Generation JSON Repair

The central theme is a shift from a linear, deterministic repair pipeline to a **probabilistic and context-aware repair engine**. This engine would explore multiple potential fixes and select the most likely valid JSON structure.

### 1. Probabilistic Repair Model & Cost System

-   **Concept**: Instead of a layer making a single, definitive change, it proposes multiple *repair candidates*.
-   **Cost Assignment**: Each candidate is assigned a "cost" (or negative log-likelihood). This cost quantifies how drastic or unusual the repair is.
    -   Simple fixes (e.g., correcting a quote type) have low costs.
    -   Complex changes (e.g., deleting a significant portion of text or deeply restructuring nested elements) have high costs.
-   **Goal**: To find the repair path that results in valid JSON with the minimum total cost. This reframes repair as finding the "most probable valid JSON given the malformed input."

### 2. Beam Search Engine

-   **Concept**: To manage the exploration of multiple repair candidates without exponential complexity, a **beam search** algorithm would be employed.
-   **Workflow**:
    1.  The engine starts with the initial input as the first candidate (cost 0).
    2.  Each layer processes the current set of promising candidates (those within the "beam").
    3.  A layer can generate multiple new candidates from each input candidate.
    4.  After each layer, the engine prunes the expanded list of candidates, keeping only the top `N` (the `beam_width`) lowest-cost candidates.
    5.  This process continues through all layers.
-   **Outcome**: The final selection is the candidate with the lowest cumulative cost that successfully validates as JSON.
-   **Benefit**: This allows JsonRemedy to explore various repair hypotheses simultaneously and choose the globally most plausible one, rather than getting stuck on a locally optimal but incorrect fix.

### 3. Enhanced Contextual Awareness

-   **Concept**: To make more informed repair decisions and assign costs more accurately, the `JsonContext` (the data structure tracking the state of parsing) needs to be significantly enriched.
-   **Enhancements**: Beyond basic state (e.g., inside an object, inside an array), the context should track:
    -   `last_significant_char`: The last non-whitespace character encountered.
    -   `last_token_type`: The type of the last logical JSON token (e.g., string, number, brace).
    -   `lookahead_buffer`: A small buffer of upcoming characters to allow for more informed decisions without extensive re-parsing.
-   **Benefit**: A richer context enables more nuanced heuristics. For example, the cost of inserting a comma can be very low if the `last_token_type` was a value and the next token also appears to be a value.

### 4. Declarative Rule Set for Heuristics

-   **Concept**: Many complex repair heuristics currently embedded in imperative code (as seen in some other JSON repair libraries) should be codified as a **declarative, extensible rule set**.
-   **Structure**: Each rule would define:
    -   A `name` for the rule.
    -   A `context_pattern` to match against the current `JsonContext`.
    -   A `char_pattern` to match against the upcoming text.
    -   The `repair` action to take (e.g., insert character, replace text).
    -   The `cost` associated with applying this repair.
-   **Benefit**: This approach makes the repair logic more transparent, easier to understand, extend, test, and maintain. Complex decision-making becomes a matter of defining and ordering rules.

## Implications

Adopting these innovations would represent a significant evolution for JsonRemedy:

-   **Increased Robustness**: Ability to handle more ambiguous and complex errors by exploring multiple solutions.
-   **Greater Accuracy**: The cost system, informed by rich context, can lead to more semantically correct repairs.
-   **Improved Extensibility**: New repair strategies can be added more easily via the declarative rule set.
-   **Principled Design**: Moves from purely heuristic-based fixes to a more formal, tunable model of repair.

These ideas lay the groundwork for a truly intelligent JSON repair system. Further documents will explore specific aspects of this vision in more detail.
