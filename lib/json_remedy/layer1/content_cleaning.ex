defmodule JsonRemedy.Layer1.ContentCleaning do
  @moduledoc """
  Layer 1: Content Cleaning - Removes non-JSON content and normalizes encoding.

  This layer handles:
  - Code fence removal (```json ... ```)
  - Comment stripping (// and /* */)
  - Wrapper text extraction (HTML, prose)
  - Encoding normalization

  Uses regex-based processing as it's the right tool for these content cleaning tasks.
  """

  @behaviour JsonRemedy.LayerBehaviour

  alias JsonRemedy.LayerBehaviour

  # Import types from LayerBehaviour
  @type repair_action :: LayerBehaviour.repair_action()
  @type repair_context :: LayerBehaviour.repair_context()
  @type layer_result :: LayerBehaviour.layer_result()

  @doc """
  Process input string and apply Layer 1 content cleaning repairs.

  Returns:
  - `{:ok, processed_input, updated_context}` - Layer completed successfully
  - `{:continue, input, context}` - Layer doesn't apply, pass to next layer  
  - `{:error, reason}` - Layer failed, stop pipeline
  """
  @spec process(input :: String.t(), context :: repair_context()) :: layer_result()
  def process(input, context) do
    {cleaned_input, new_repairs} =
      input
      |> remove_code_fences()
      |> remove_comments()
      |> extract_json_content_internal()
      |> normalize_encoding_internal()

    updated_context = %{
      repairs: context.repairs ++ new_repairs,
      options: context.options,
      metadata: Map.put(Map.get(context, :metadata, %{}), :layer1_processed, true)
    }

    {:ok, cleaned_input, updated_context}
  rescue
    error ->
      {:error, "Layer 1 Content Cleaning failed: #{inspect(error)}"}
  end

  @doc """
  Remove code fences from input while preserving fence content in strings.
  """
  @spec remove_code_fences(input :: String.t()) :: {String.t(), [repair_action()]}
  def remove_code_fences(input) do
    # Multiple patterns for different fence formats
    fence_patterns = [
      # Standard
      ~r/```(?:json|javascript|js|JSON)?\s*\n(.*?)\n```/ms,
      # No newlines
      ~r/```(?:json|javascript|js|JSON)?\s*(.*?)```/ms,
      # Malformed opening
      ~r/``(?:json|javascript|js|JSON)?\s*(.*?)```/ms,
      # Malformed closing
      ~r/```(?:json|javascript|js|JSON)?\s*(.*?)``/ms
    ]

    # Try each pattern
    fence_patterns
    |> Enum.reduce_while({input, []}, fn pattern, {current_input, repairs} ->
      case Regex.run(pattern, current_input) do
        [full_match, content] ->
          # Check if this is inside a string (basic check)
          if inside_string?(current_input, full_match) do
            {:cont, {current_input, repairs}}
          else
            repair = %{
              layer: :content_cleaning,
              action: "removed code fences",
              position: nil,
              original: full_match,
              replacement: String.trim(content)
            }

            {:halt, {String.trim(content), repairs ++ [repair]}}
          end

        nil ->
          {:cont, {current_input, repairs}}
      end
    end)
  end

  @doc """
  Strip comments while preserving comment-like content in strings.
  """
  @spec remove_comments(input :: {String.t(), [repair_action()]}) ::
          {String.t(), [repair_action()]}
  def remove_comments({input, existing_repairs}) do
    {result, line_comment_repairs} = remove_line_comments(input)
    {result, block_comment_repairs} = remove_block_comments(result)

    all_repairs = existing_repairs ++ line_comment_repairs ++ block_comment_repairs
    {result, all_repairs}
  end

  @doc """
  Extract JSON from wrapper text (HTML, prose, etc.).
  """
  @spec extract_json_content_internal(input :: {String.t(), [repair_action()]}) ::
          {String.t(), [repair_action()]}
  def extract_json_content_internal({input, existing_repairs}) do
    # Try to extract JSON from HTML tags first
    {result, html_repairs} = extract_from_html_tags(input)

    # Then try to extract from prose/text
    {result, prose_repairs} = extract_from_prose(result)

    all_repairs = existing_repairs ++ html_repairs ++ prose_repairs
    {result, all_repairs}
  end

  @doc """
  Normalize text encoding to UTF-8.
  """
  @spec normalize_encoding_internal(input :: {String.t(), [repair_action()]}) ::
          {String.t(), [repair_action()]}
  def normalize_encoding_internal({input, existing_repairs}) do
    if String.valid?(input) do
      {input, existing_repairs}
    else
      # For now, just ensure it's valid UTF-8
      # In a real implementation, we'd handle various encoding issues
      cleaned = String.replace(input, ~r/[^\x00-\x7F]/, "", global: true)

      repair = %{
        layer: :content_cleaning,
        action: "normalized encoding",
        position: nil,
        original: nil,
        replacement: nil
      }

      {cleaned, existing_repairs ++ [repair]}
    end
  end

  # LayerBehaviour callback implementations

  @doc """
  Check if this layer can handle the given input.
  Layer 1 can handle any text input that may contain JSON with wrapping content.
  """
  @spec supports?(input :: String.t()) :: boolean()
  def supports?(input) when is_binary(input) do
    # Layer 1 can attempt to process any string input
    # It looks for code fences, comments, or wrapper content
    # Use fast string pattern matching instead of expensive operations
    String.contains?(input, "```") or
      String.contains?(input, "//") or
      String.contains?(input, "/*") or
      String.contains?(input, "<pre>") or
      String.contains?(input, "<code>") or
      long_text_with_content?(input)
  end

  def supports?(_), do: false

  @doc """
  Return the priority order for this layer.
  Layer 1 (Content Cleaning) should run first in the pipeline.
  """
  @spec priority() :: non_neg_integer()
  def priority, do: 1

  @doc """
  Return a human-readable name for this layer.
  """
  @spec name() :: String.t()
  def name, do: "Content Cleaning"

  @doc """
  Validate layer configuration and options.
  Layer 1 accepts options for enabling/disabling specific cleaning features.
  """
  @spec validate_options(options :: keyword()) :: :ok | {:error, String.t()}
  def validate_options(options) when is_list(options) do
    valid_keys = [:remove_comments, :remove_code_fences, :extract_from_html, :normalize_encoding]

    invalid_keys = Keyword.keys(options) -- valid_keys

    if Enum.empty?(invalid_keys) do
      # Validate option values
      case validate_option_values(options) do
        :ok -> :ok
        error -> error
      end
    else
      {:error, "Invalid options: #{inspect(invalid_keys)}. Valid options: #{inspect(valid_keys)}"}
    end
  end

  def validate_options(_), do: {:error, "Options must be a keyword list"}

  defp validate_option_values(options) do
    boolean_options = [
      :remove_comments,
      :remove_code_fences,
      :extract_from_html,
      :normalize_encoding
    ]

    Enum.reduce_while(options, :ok, fn {key, value}, _acc ->
      if key in boolean_options and not is_boolean(value) do
        {:halt, {:error, "Option #{key} must be a boolean, got: #{inspect(value)}"}}
      else
        {:cont, :ok}
      end
    end)
  end

  # Public API functions that match the API contracts

  @doc """
  Strip comments while preserving comment-like content in strings.
  Public API version that takes string input directly.
  """
  @spec strip_comments(input :: String.t()) :: {String.t(), [repair_action()]}
  def strip_comments(input) when is_binary(input) do
    remove_comments({input, []})
  end

  @doc """
  Extract JSON from wrapper text (HTML, prose, etc.).
  Public API version that takes string input directly.
  """
  @spec extract_json_content(input :: String.t()) :: {String.t(), [repair_action()]}
  def extract_json_content(input) when is_binary(input) do
    # Need to rename one of these functions to avoid conflicts
    # For now, call the internal pipeline function directly
    extract_json_content_internal({input, []})
  end

  @doc """
  Normalize text encoding to UTF-8.
  Public API version that takes string input directly.
  """
  @spec normalize_encoding(input :: String.t()) :: {String.t(), [repair_action()]}
  def normalize_encoding(input) when is_binary(input) do
    # Need to rename one of these functions to avoid conflicts
    # For now, call the internal pipeline function directly
    normalize_encoding_internal({input, []})
  end

  # Private helper functions

  defp remove_line_comments(input) do
    # Remove // comments but preserve them inside strings
    lines = String.split(input, "\n")

    {processed_lines, repairs} =
      lines
      |> Enum.with_index()
      |> Enum.map_reduce([], fn {line, _index}, acc_repairs ->
        if String.contains?(line, "//") and not line_has_comment_in_string?(line) do
          cleaned_line = String.replace(line, ~r/\s*\/\/.*$/, "")

          repair = %{
            layer: :content_cleaning,
            action: "removed line comment",
            position: nil,
            original: line,
            replacement: cleaned_line
          }

          {cleaned_line, [repair | acc_repairs]}
        else
          {line, acc_repairs}
        end
      end)

    result = Enum.join(processed_lines, "\n")
    {result, Enum.reverse(repairs)}
  end

  defp remove_block_comments(input) do
    # Remove /* */ comments but preserve them inside strings
    # Use a greedy pattern to handle nested comments properly
    comment_pattern = ~r/\/\*.*\*\//ms

    # Find all matches and their positions
    matches = Regex.scan(comment_pattern, input, return: :index)

    # Filter out matches that are inside strings and collect repairs
    {filtered_matches, repairs} =
      matches
      |> Enum.map(fn [{start, length}] ->
        original = String.slice(input, start, length)
        inside_string = comment_inside_string?(input, start)

        repair =
          if not inside_string do
            %{
              layer: :content_cleaning,
              action: "removed block comment",
              position: start,
              original: original,
              replacement: ""
            }
          end

        {{start, length, inside_string}, repair}
      end)
      |> Enum.reduce({[], []}, fn {{start, length, inside_string}, repair},
                                  {matches_acc, repairs_acc} ->
        if inside_string do
          {matches_acc, repairs_acc}
        else
          {[{start, length} | matches_acc], [repair | repairs_acc]}
        end
      end)

    # Remove comments by replacing them with empty string (process in reverse order to maintain positions)
    result =
      filtered_matches
      |> Enum.sort_by(fn {start, _length} -> start end, :desc)
      |> Enum.reduce(input, fn {start, length}, acc ->
        before = String.slice(acc, 0, start)
        after_part = String.slice(acc, start + length, String.length(acc))
        before <> after_part
      end)

    {result, Enum.reverse(repairs)}
  end

  defp extract_from_html_tags(input) do
    # Pattern to match HTML tags containing JSON
    html_patterns = [
      ~r/<pre[^>]*>(.*?)<\/pre>/ms,
      ~r/<code[^>]*>(.*?)<\/code>/ms,
      ~r/<json[^>]*>(.*?)<\/json>/ms
    ]

    {result, repairs} =
      html_patterns
      |> Enum.reduce({input, []}, fn pattern, {current_input, acc_repairs} ->
        case Regex.run(pattern, current_input) do
          [_full_match, content] ->
            repair = %{
              layer: :content_cleaning,
              action: "extracted JSON from HTML wrapper",
              position: nil,
              original: nil,
              replacement: nil
            }

            {String.trim(content), [repair | acc_repairs]}

          nil ->
            {current_input, acc_repairs}
        end
      end)

    {result, Enum.reverse(repairs)}
  end

  defp extract_from_prose(input) do
    # Simple heuristic: if input contains clear JSON structure
    # but also has a lot of prose, try to extract the JSON part

    # Look for JSON-like patterns: starts with { or [, contains quotes and colons/commas
    json_pattern = ~r/(\{.*?\}|\[.*?\])/ms

    if String.length(input) > 100 and
         not String.starts_with?(String.trim(input), ["{", "["]) and
         Regex.match?(json_pattern, input) do
      case Regex.run(json_pattern, input) do
        [_full_match, json_content] ->
          repair = %{
            layer: :content_cleaning,
            action: "extracted JSON from wrapper text",
            position: nil,
            original: input,
            replacement: json_content
          }

          {String.trim(json_content), [repair]}

        [json_content] ->
          # Single capture group case
          repair = %{
            layer: :content_cleaning,
            action: "extracted JSON from wrapper text",
            position: nil,
            original: input,
            replacement: json_content
          }

          {String.trim(json_content), [repair]}

        nil ->
          {input, []}
      end
    else
      {input, []}
    end
  end

  # Helper functions for string detection

  # Fast check for long text that likely contains JSON content
  defp long_text_with_content?(input) do
    byte_size(input) > 100 and
      not (String.starts_with?(input, "{") or String.starts_with?(input, "["))
  end

  defp inside_string?(input, target) when is_binary(target) do
    # Find the position of target in input
    case String.split(input, target, parts: 2) do
      [before, _after] ->
        string_context_at_position?(input, String.length(before))

      [_] ->
        false
    end
  end

  defp line_has_comment_in_string?(line) do
    # Simple check: count quotes before //
    comment_pos = String.split(line, "//", parts: 2) |> hd() |> String.length()
    before_comment = String.slice(line, 0, comment_pos)

    # Count unescaped quotes
    quote_count =
      before_comment
      # Remove escaped quotes
      |> String.replace(~r/\\"/, "")
      |> String.graphemes()
      |> Enum.count(&(&1 == "\""))

    # Odd number means we're inside a string
    rem(quote_count, 2) != 0
  end

  defp comment_inside_string?(input, position) do
    string_context_at_position?(input, position)
  end

  defp string_context_at_position?(input, position) do
    before = String.slice(input, 0, position)

    # Count unescaped quotes before this position
    quote_count =
      before
      # Remove escaped quotes
      |> String.replace(~r/\\"/, "")
      |> String.graphemes()
      |> Enum.count(&(&1 == "\""))

    # Odd number means we're inside a string
    rem(quote_count, 2) != 0
  end
end
