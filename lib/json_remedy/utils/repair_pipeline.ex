defmodule JsonRemedy.Utils.RepairPipeline do
  @moduledoc false

  alias JsonRemedy.Layer1.ContentCleaning
  alias JsonRemedy.Layer2.StructuralRepair
  alias JsonRemedy.Layer3.HardcodedPatterns
  alias JsonRemedy.Layer3.ObjectMerger
  alias JsonRemedy.Layer3.SyntaxNormalization
  alias JsonRemedy.Layer4.Validation
  alias JsonRemedy.Utils.Preprocessing
  alias JsonRemedy.Utils.StructureCoercion

  @spec repair_single(String.t(), keyword()) :: {:ok, term()} | {:error, String.t()}
  def repair_single(input, options \\ []) when is_binary(input) do
    context = %{repairs: [], options: options, metadata: %{}}

    input_after_merge =
      if Application.get_env(:json_remedy, :enable_object_merging, true) do
        {merged, _repairs} = ObjectMerger.merge_object_boundaries(input)
        merged
      else
        input
      end

    input_after_hardcoded =
      if Application.get_env(:json_remedy, :enable_early_hardcoded_patterns, true) do
        input_after_merge
        |> HardcodedPatterns.normalize_smart_quotes()
        |> HardcodedPatterns.fix_doubled_quotes()
        |> Preprocessing.extract_code_fence_json_in_string_values()
        |> strip_trailing_code_fences()
        |> fix_missing_opening_quotes()
        |> fix_embedded_quotes_in_strings()
        |> fix_unclosed_string_before_delimiter()
        |> Preprocessing.split_truncated_object_key_in_array()
      else
        input_after_merge
      end

    input_after_structure = StructureCoercion.coerce_object_to_array(input_after_hardcoded)

    with {:ok, output1, context1} <- ContentCleaning.process(input_after_structure, context),
         {:ok, output2, context2} <- StructuralRepair.process(output1, context1),
         {:ok, output3, context3} <- SyntaxNormalization.process(output2, context2),
         {:ok, parsed, _final_context} <- Validation.process(output3, context3) do
      {:ok, parsed}
    else
      {:continue, _, _} -> {:error, "validation failed"}
      {:error, reason} -> {:error, reason}
    end
  end

  # Strip trailing code fences (LLM truncation artifact)
  # Pattern: ``` at the end of the input, possibly preceded by }
  # This must run BEFORE Layer 2 to prevent incorrect structure counting
  defp strip_trailing_code_fences(content) when is_binary(content) do
    content
    # Pattern 1: "string}``` → "string"}
    |> String.replace(~r/\"([^\"\\]*(?:\\.[^\"\\]*)*)\}```\s*$/u, "\"\\1\"}")
    # Pattern 2: "string]``` → "string"]
    |> String.replace(~r/\"([^\"\\]*(?:\\.[^\"\\]*)*)\]```\s*$/u, "\"\\1\"]")
    # Pattern 3: Just trailing ``` after a properly closed string
    |> String.replace(~r/\"```\s*$/u, "\"")
    # Pattern 4: Plain trailing ```
    |> String.replace(~r/```\s*$/u, "")
  end

  # Fix missing opening quotes on values
  # Pattern: : value" or , value" where the opening quote is missing
  defp fix_missing_opening_quotes(content) when is_binary(content) do
    content
    # Pattern 1: Object value missing opening quote - : identifier" ,
    # Match: : abcdef", and transform to : "abcdef",
    |> String.replace(
      ~r/(:\s*)([a-zA-Z][a-zA-Z0-9_]*)"(\s*[,\}\]])/u,
      "\\1\"\\2\"\\3"
    )
    # Pattern 2: Array value missing opening quote after string - "string" identifier"
    # Match: "value1" value2", and transform to "value1", "value2",
    |> String.replace(
      ~r/("\s+)([a-zA-Z][a-zA-Z0-9_]*)"(\s*[,\]\}])/u,
      "\",\"\\2\"\\3"
    )
    # Pattern 3: Array value missing opening quote after string with space before close
    # Match: "string" identifier" ] and transform to "string", "identifier"]
    |> String.replace(
      ~r/("\s+)([a-zA-Z][a-zA-Z0-9_]*)"\s*\]/u,
      "\", \"\\2\"]"
    )
    # Pattern 4: Number with trailing quote (orphan quote) - : 12345" ,
    # Match: : 12345", and transform to : 12345,
    |> String.replace(
      ~r/(:\s*)(\d+)"(\s*[,\}\]])/u,
      "\\1\\2\\3"
    )
  end

  # Fix embedded quotes in strings
  # Pattern: "content1"content2" where content2 starts with a letter
  # This indicates the quote after content1 is embedded, not a terminator
  # Example: {"key": "v"alue"} → {"key": "v\"alue\""}
  defp fix_embedded_quotes_in_strings(content) when is_binary(content) do
    content
    # Pattern 1: Object value with double embedded quotes - "text1"text2"}
    # Matches: ": "v"alue"} or similar
    |> String.replace(
      ~r/(:\s*)"([^"\\]*)"([a-zA-Z][^"\\]*)"(\})/u,
      "\\1\"\\2\\\"\\3\\\"\"\\4"
    )
    # Pattern 2: Array value with double embedded quotes - ["text1"text2"]
    |> String.replace(
      ~r/([\[\,]\s*)"([^"\\]*)"([a-zA-Z][^"\\]*)"([\]\,])/u,
      "\\1\"\\2\\\"\\3\\\"\"\\4"
    )
    # Pattern 3: Object value with embedded quote followed by comma - "text1"text2",
    |> String.replace(
      ~r/(:\s*)"([^"\\]*)"([a-zA-Z][^"\\]*)"(\s*,)/u,
      "\\1\"\\2\\\"\\3\"\\4"
    )
    # Pattern 4: Object value with embedded quote followed by next key - "text1"text2", "key
    |> String.replace(
      ~r/(:\s*)"([^"\\]*)"([a-zA-Z][^"\\,]*)",(\s*")/u,
      "\\1\"\\2\\\"\\3\",\\4"
    )
  end

  # Fix strings that end with } or ] without closing quote
  # IMPORTANT:
  # 1. Require at least one char to avoid matching valid JSON like "value"}
  # 2. Exclude JSON structural chars (: [ ] { }), comma, and whitespace at start
  # 3. Content must start with a letter (not space or digit) to avoid matching JSON values
  defp fix_unclosed_string_before_delimiter(content) when is_binary(content) do
    content
    # Match "string} at end - content must start with letter, not whitespace/digit
    |> String.replace(~r/\"([a-zA-Z][^\"\\:\[\]{},]*(?:\\.[^\"\\]*)*)\}(\s*)$/u, "\"\\1\"\\2}")
    # Match "string] at end - content must start with letter
    |> String.replace(~r/\"([a-zA-Z][^\"\\:\[\]{},]*(?:\\.[^\"\\]*)*)\](\s*)$/u, "\"\\1\"\\2]")
    # Match "string} followed by more content - content must start with letter
    |> String.replace(~r/\"([a-zA-Z][^\"\\:\[\]{},]*)\}([,\]\}])/u, "\"\\1\"}\\2")
    # Match "string] followed by more content
    |> String.replace(~r/\"([a-zA-Z][^\"\\:\[\]{},]*)\]([,\]\}])/u, "\"\\1\"]\\2")
  end
end
