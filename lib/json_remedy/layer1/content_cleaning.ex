defmodule JsonRemedy.Layer1.ContentCleaning do
  @moduledoc """
  Layer 1: Content Cleaning - Removes non-JSON content and normalizes encoding.

  This layer handles:
  - Code fence removal (```json ... ```)
  - Comment stripping (// and /* */)
  - Wrapper text extraction (HTML, prose)
  - Encoding normalization

  Uses direct string methods instead of regex for better performance and clearer code.
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
      |> strip_trailing_dots_internal()
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
    # Check for code fences using string methods
    if has_code_fences?(input) and not fence_in_string?(input) do
      extract_from_code_fence(input)
    else
      {input, []}
    end
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

    # Finally, remove any trailing wrapper text after JSON
    {result, trailing_repairs} = remove_trailing_wrapper_text(result)

    all_repairs = existing_repairs ++ html_repairs ++ prose_repairs ++ trailing_repairs
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
      # Remove non-ASCII characters using direct character filtering
      cleaned = filter_to_ascii(input)

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

  @doc """
  Strip trailing dots from truncated content (Gemini max_output_tokens pattern).

  When LLMs like Gemini hit max_output_tokens, they sometimes fill remaining tokens
  with dots instead of stopping cleanly. This results in truncated JSON followed
  by thousands of trailing dots.

  This function detects and strips these trailing dots while preserving:
  - Dots inside string values
  - Legitimate ellipsis (...) in content
  - Valid JSON structure
  """
  @spec strip_trailing_dots_internal(input :: {String.t(), [repair_action()]}) ::
          {String.t(), [repair_action()]}
  def strip_trailing_dots_internal({input, existing_repairs}) do
    case strip_trailing_dots(input) do
      {^input, []} ->
        # No change needed
        {input, existing_repairs}

      {cleaned, new_repairs} ->
        {cleaned, existing_repairs ++ new_repairs}
    end
  end

  # Minimum threshold: 10 dots to be considered truncation
  # This avoids stripping legitimate ellipsis (...) or a few trailing dots
  @trailing_dots_threshold 10

  @doc """
  Strip trailing dots from input.

  Public API version that takes string input directly.
  Detects and removes trailing dots that indicate truncation (10+ consecutive dots).
  """
  @spec strip_trailing_dots(input :: String.t()) :: {String.t(), [repair_action()]}
  def strip_trailing_dots(input) when is_binary(input) do
    # Find trailing dots pattern: dots (possibly with whitespace/newlines) at end
    case find_trailing_dots_start(input) do
      nil ->
        {input, []}

      {start_pos, dots_count} when dots_count >= @trailing_dots_threshold ->
        # Strip from the start position to the end
        cleaned = String.slice(input, 0, start_pos) |> String.trim_trailing()

        repair = %{
          layer: :content_cleaning,
          action: "stripped #{dots_count} trailing dots (LLM truncation pattern)",
          position: start_pos,
          original: nil,
          replacement: nil
        }

        {cleaned, [repair]}

      {_start_pos, _dots_count} ->
        # Not enough dots to be truncation
        {input, []}
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
  @spec priority() :: 1
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

  # Private helper functions - all using direct string methods instead of regex

  # Code Fence Handling
  # Only treat as code fence if:
  # 1. Input starts with ``` or `` (after trimming) - proper fence opening
  # 2. OR has at least 2 occurrences of ``` (opening and closing)
  # This prevents trailing ``` (LLM truncation artifact) from being treated as fences
  defp has_code_fences?(input) do
    trimmed = String.trim(input)
    fence_count = length(String.split(input, "```")) - 1

    # Proper code fence: starts with ``` or `` (malformed), or has both opening and closing
    String.starts_with?(trimmed, "```") or
      String.starts_with?(trimmed, "``") or
      fence_count >= 2
  end

  defp fence_in_string?(input) do
    # Check if ``` appears inside a string literal
    parts = String.split(input, "```", parts: 2)

    if length(parts) == 2 do
      [before_fence, _after] = parts
      quote_count = count_unescaped_quotes(before_fence)
      rem(quote_count, 2) != 0
    else
      false
    end
  end

  defp extract_from_code_fence(input) do
    lines = String.split(input, "\n")

    case find_code_fence_boundaries(lines) do
      {start_idx, end_idx} ->
        # Extract content between fences
        content_lines = Enum.slice(lines, (start_idx + 1)..(end_idx - 1))
        content = Enum.join(content_lines, "\n")

        repair = %{
          layer: :content_cleaning,
          action: "removed code fences",
          position: nil,
          original: input,
          replacement: String.trim(content)
        }

        {String.trim(content), [repair]}

      nil ->
        # Malformed fences - try to extract anyway
        extract_malformed_fence_content(input)
    end
  end

  defp find_code_fence_boundaries(lines) do
    start_idx =
      Enum.find_index(lines, fn line ->
        trimmed = String.trim(line)
        starts_with_fence?(trimmed)
      end)

    if start_idx do
      # Look for closing fence after the start
      end_idx =
        Enum.find_index(Enum.drop(lines, start_idx + 1), fn line ->
          trimmed = String.trim(line)
          String.starts_with?(trimmed, "```") or String.starts_with?(trimmed, "``")
        end)

      if end_idx do
        # Adjust index since we dropped elements
        actual_end_idx = start_idx + 1 + end_idx
        {start_idx, actual_end_idx}
      else
        nil
      end
    else
      nil
    end
  end

  defp starts_with_fence?(line) do
    String.starts_with?(line, "```") or String.starts_with?(line, "``")
  end

  defp extract_malformed_fence_content(input) do
    # Handle cases like ```json\n{content} or {content}\n```
    cond do
      # Check for malformed fences like ``json first (before checking ```)
      String.starts_with?(input, "``") and not String.starts_with?(input, "```") ->
        # Handle malformed fences like ``json\n{content}```
        parts = String.split(input, "``")

        if length(parts) >= 2 do
          # Find the part with JSON content
          content_part =
            Enum.find(parts, fn part ->
              trimmed = String.trim(part)
              String.contains?(trimmed, "{") or String.contains?(trimmed, "[")
            end)

          if content_part do
            content = String.trim(content_part)
            # Remove trailing ``` if present
            content = String.replace_suffix(content, "```", "")
            content = remove_language_prefix(content)

            repair = %{
              layer: :content_cleaning,
              action: "removed code fences",
              position: nil,
              original: input,
              replacement: content
            }

            {content, [repair]}
          else
            {input, []}
          end
        else
          {input, []}
        end

      String.contains?(input, "```") ->
        parts = String.split(input, "```")

        if length(parts) >= 2 do
          # Take the middle part that likely contains JSON
          content = Enum.at(parts, 1) || Enum.at(parts, 0)
          content = String.trim(content)

          # Remove language identifiers
          content = remove_language_prefix(content)

          repair = %{
            layer: :content_cleaning,
            action: "removed code fences",
            position: nil,
            original: input,
            replacement: content
          }

          {content, [repair]}
        else
          {input, []}
        end

      true ->
        {input, []}
    end
  end

  defp remove_language_prefix(content) do
    lines = String.split(content, "\n")

    case lines do
      [first_line | rest] ->
        if language_line?(first_line) do
          Enum.join(rest, "\n")
        else
          content
        end

      _ ->
        content
    end
  end

  defp language_line?(line) do
    trimmed = String.trim(line)
    language_keywords = ["json", "javascript", "js", "JSON"]

    Enum.any?(language_keywords, fn keyword -> String.contains?(trimmed, keyword) end) and
      not String.contains?(trimmed, "{") and not String.contains?(trimmed, "[")
  end

  # Comment Removal using direct string methods
  defp remove_line_comments(input) do
    lines = String.split(input, "\n")

    {processed_lines, repairs} =
      lines
      |> Enum.with_index()
      |> Enum.map_reduce([], fn {line, _index}, acc_repairs ->
        if String.contains?(line, "//") and not line_has_comment_in_string?(line) do
          cleaned_line = remove_line_comment_from_line(line)

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

  defp remove_line_comment_from_line(line) do
    # Find // that's not inside a string
    case find_line_comment_position(line) do
      nil -> line
      pos -> String.slice(line, 0, pos) |> String.trim_trailing()
    end
  end

  defp find_line_comment_position(line) do
    find_line_comment_position(line, 0, false)
  end

  defp find_line_comment_position(<<>>, _pos, _in_string), do: nil

  defp find_line_comment_position(<<"//", _rest::binary>>, pos, false), do: pos

  defp find_line_comment_position(<<"\"", rest::binary>>, pos, in_string) do
    find_line_comment_position(rest, pos + 1, not in_string)
  end

  defp find_line_comment_position(<<"\\\"", rest::binary>>, pos, in_string) do
    # Skip escaped quote
    find_line_comment_position(rest, pos + 2, in_string)
  end

  defp find_line_comment_position(<<_char::utf8, rest::binary>>, pos, in_string) do
    find_line_comment_position(rest, pos + 1, in_string)
  end

  defp remove_block_comments(input) do
    case find_block_comment(input) do
      nil ->
        {input, []}

      {start_pos, end_pos, _comment_text} ->
        if comment_inside_string?(input, start_pos) do
          {input, []}
        else
          before =
            if start_pos > 0 do
              binary_part(input, 0, start_pos)
            else
              ""
            end

          comment_length = end_pos - start_pos + 2
          after_start = end_pos + 2

          after_comment =
            if after_start >= byte_size(input) do
              ""
            else
              binary_part(input, after_start, byte_size(input) - after_start)
            end

          result = before <> after_comment

          repair = %{
            layer: :content_cleaning,
            action: "removed block comment",
            position: start_pos,
            original: binary_part(input, start_pos, comment_length),
            replacement: ""
          }

          # Recursively remove more block comments
          {final_result, more_repairs} = remove_block_comments(result)
          {final_result, [repair | more_repairs]}
        end
    end
  end

  defp find_block_comment(input) do
    find_block_comment(input, 0)
  end

  defp find_block_comment(input, start_offset) do
    case find_substring_position(input, "/*", start_offset) do
      nil ->
        nil

      start_pos ->
        # For nested comments, find the matching */ by counting nesting levels
        case find_matching_block_comment_end(input, start_pos + 2) do
          nil ->
            nil

          end_pos ->
            comment_length = end_pos - start_pos + 2
            comment_text = String.slice(input, start_pos, comment_length)
            {start_pos, end_pos, comment_text}
        end
    end
  end

  defp find_matching_block_comment_end(input, start_pos) do
    find_matching_block_comment_end(input, start_pos, 1)
  end

  defp find_matching_block_comment_end(input, pos, nesting_level) when nesting_level > 0 do
    case {find_substring_position(input, "/*", pos), find_substring_position(input, "*/", pos)} do
      {nil, nil} ->
        nil

      {nil, close_pos} ->
        if nesting_level == 1,
          do: close_pos,
          else: find_matching_block_comment_end(input, close_pos + 2, nesting_level - 1)

      {_open_pos, nil} ->
        nil

      {open_pos, close_pos} when open_pos < close_pos ->
        find_matching_block_comment_end(input, open_pos + 2, nesting_level + 1)

      {_open_pos, close_pos} ->
        if nesting_level == 1,
          do: close_pos,
          else: find_matching_block_comment_end(input, close_pos + 2, nesting_level - 1)
    end
  end

  defp find_matching_block_comment_end(_input, _pos, 0), do: nil

  defp find_substring_position(string, substring, start_offset) do
    total_size = byte_size(string)

    if start_offset >= total_size do
      nil
    else
      slice_size = total_size - start_offset
      slice = binary_part(string, start_offset, slice_size)

      case :binary.match(slice, substring) do
        {match_start, _length} -> start_offset + match_start
        :nomatch -> nil
      end
    end
  end

  # HTML Tag Extraction using direct string methods
  defp extract_from_html_tags(input) do
    cond do
      String.contains?(input, "<pre>") and String.contains?(input, "</pre>") ->
        extract_from_tag(input, "<pre>", "</pre>", "extracted JSON from HTML wrapper")

      String.contains?(input, "<code>") and String.contains?(input, "</code>") ->
        extract_from_tag(input, "<code>", "</code>", "extracted JSON from HTML wrapper")

      String.contains?(input, "<json>") and String.contains?(input, "</json>") ->
        extract_from_tag(input, "<json>", "</json>", "extracted JSON from HTML wrapper")

      true ->
        {input, []}
    end
  end

  defp extract_from_tag(input, open_tag, close_tag, action_description) do
    case String.split(input, open_tag, parts: 2) do
      [_before, rest] ->
        case String.split(rest, close_tag, parts: 2) do
          [content, _after] ->
            cleaned_content = String.trim(content)

            repair = %{
              layer: :content_cleaning,
              action: action_description,
              position: nil,
              original: nil,
              replacement: nil
            }

            {cleaned_content, [repair]}

          [_single_part] ->
            {input, []}
        end

      [_single_part] ->
        {input, []}
    end
  end

  # Prose Extraction using direct string methods
  defp extract_from_prose(input) do
    # Simple heuristic: if input contains clear JSON structure
    # but also has a lot of prose, try to extract the JSON part
    if should_extract_from_prose?(input) do
      case extract_json_like_content(input) do
        nil ->
          {input, []}

        json_content ->
          repair = %{
            layer: :content_cleaning,
            action: "extracted JSON from wrapper text",
            position: nil,
            original: input,
            replacement: json_content
          }

          {String.trim(json_content), [repair]}
      end
    else
      {input, []}
    end
  end

  defp should_extract_from_prose?(input) do
    String.length(input) > 100 and
      not String.starts_with?(String.trim(input), "{") and
      not String.starts_with?(String.trim(input), "[") and
      (String.contains?(input, "{") or String.contains?(input, "["))
  end

  defp extract_json_like_content(input) do
    # Look for content that starts with { or [
    cond do
      json_pos = find_json_start(input, "{") ->
        extract_balanced_content(input, json_pos, "{", "}")

      json_pos = find_json_start(input, "[") ->
        extract_balanced_content(input, json_pos, "[", "]")

      true ->
        nil
    end
  end

  defp find_json_start(input, start_char) do
    case String.split(input, start_char, parts: 2) do
      [before, _after] -> String.length(before)
      [_single] -> nil
    end
  end

  defp extract_balanced_content(input, start_pos, open_char, close_char) do
    total_size = byte_size(input)

    if start_pos >= total_size do
      nil
    else
      substring = binary_part(input, start_pos, total_size - start_pos)

      case find_balanced_end(substring, open_char, close_char) do
        nil -> nil
        end_pos -> binary_part(substring, 0, end_pos + byte_size(close_char))
      end
    end
  end

  defp find_balanced_end(string, open_char, close_char) do
    find_balanced_end(string, open_char, close_char, 0, 0, false)
  end

  defp find_balanced_end(<<>>, _open, _close, _pos, _balance, _in_string), do: nil

  defp find_balanced_end(<<"\"", rest::binary>>, open, close, pos, balance, in_string) do
    find_balanced_end(rest, open, close, pos + 1, balance, not in_string)
  end

  defp find_balanced_end(<<"\\\"", rest::binary>>, open, close, pos, balance, in_string) do
    find_balanced_end(rest, open, close, pos + 2, balance, in_string)
  end

  defp find_balanced_end(<<char::utf8, rest::binary>>, open, close, pos, balance, false)
       when <<char::utf8>> == open do
    char_size = byte_size(<<char::utf8>>)
    find_balanced_end(rest, open, close, pos + char_size, balance + 1, false)
  end

  defp find_balanced_end(<<char::utf8, rest::binary>>, open, close, pos, balance, false)
       when <<char::utf8>> == close do
    char_size = byte_size(<<char::utf8>>)
    new_balance = balance - 1

    if new_balance == 0 do
      pos
    else
      find_balanced_end(rest, open, close, pos + char_size, new_balance, false)
    end
  end

  defp find_balanced_end(<<char::utf8, rest::binary>>, open, close, pos, balance, in_string) do
    char_size = byte_size(<<char::utf8>>)
    find_balanced_end(rest, open, close, pos + char_size, balance, in_string)
  end

  # Check if a string is valid JSON (not just starts with valid char)
  defp valid_json_start?(str) do
    first_char = String.at(str, 0)

    # Must start with JSON structure delimiter, not primitives
    # This prevents "1 Volume(s) created" from being preserved
    first_char in ["{", "["]
  end

  # Remove trailing wrapper text after JSON
  defp remove_trailing_wrapper_text(input) do
    trimmed = String.trim(input)

    # Check if input starts with JSON structure
    cond do
      String.starts_with?(trimmed, "{") ->
        check_and_remove_trailing_text(input, "{", "}")

      String.starts_with?(trimmed, "[") ->
        check_and_remove_trailing_text(input, "[", "]")

      true ->
        {input, []}
    end
  end

  defp check_and_remove_trailing_text(input, open_char, close_char) do
    # Find where the JSON structure starts
    json_start =
      case String.split(input, open_char, parts: 2) do
        [prefix, _] -> byte_size(prefix)
        _ -> 0
      end

    total_size = byte_size(input)
    substring_size = total_size - json_start
    substring_from_json = binary_part(input, json_start, substring_size)

    case find_balanced_end(substring_from_json, open_char, close_char) do
      nil ->
        # Could not find balanced end, return as is
        {input, []}

      end_pos ->
        # Calculate the absolute position where JSON ends
        json_end = json_start + end_pos + 1

        # Check if there's non-whitespace content after JSON ends
        after_size = max(total_size - json_end, 0)

        after_json =
          if after_size > 0 do
            binary_part(input, json_end, after_size)
          else
            ""
          end

        after_json_trimmed = String.trim(after_json)

        cond do
          after_json_trimmed == "" ->
            # No significant trailing content
            {input, []}

          valid_json_start?(after_json_trimmed) ->
            # The "trailing" content is actually another JSON value (Pattern 1: Multiple JSON)
            # Don't remove it - let it be handled by Layer 5
            {input, []}

          true ->
            # Extract only the JSON portion, remove wrapper text
            json_content = binary_part(input, 0, json_end)

            repair = %{
              layer: :content_cleaning,
              action: "removed trailing wrapper text",
              position: json_end,
              original: input,
              replacement: json_content
            }

            {json_content, [repair]}
        end
    end
  end

  # Helper functions for string detection using direct methods

  # Fast check for long text that likely contains JSON content
  defp long_text_with_content?(input) do
    byte_size(input) > 100 and
      not (String.starts_with?(input, "{") or String.starts_with?(input, "["))
  end

  defp line_has_comment_in_string?(line) do
    # Simple check: count quotes before //
    case String.split(line, "//", parts: 2) do
      [before_comment, _after] ->
        quote_count = count_unescaped_quotes(before_comment)
        rem(quote_count, 2) != 0

      [_single_part] ->
        false
    end
  end

  defp comment_inside_string?(input, position) do
    string_context_at_position?(input, position)
  end

  defp string_context_at_position?(input, position) do
    before = String.slice(input, 0, position)
    quote_count = count_unescaped_quotes(before)
    rem(quote_count, 2) != 0
  end

  defp count_unescaped_quotes(string) do
    count_unescaped_quotes(string, 0, 0)
  end

  defp count_unescaped_quotes(<<>>, _pos, count), do: count

  defp count_unescaped_quotes(<<"\\\"", rest::binary>>, pos, count) do
    count_unescaped_quotes(rest, pos + 2, count)
  end

  defp count_unescaped_quotes(<<"\"", rest::binary>>, pos, count) do
    count_unescaped_quotes(rest, pos + 1, count + 1)
  end

  defp count_unescaped_quotes(<<_char::utf8, rest::binary>>, pos, count) do
    count_unescaped_quotes(rest, pos + 1, count)
  end

  # Encoding normalization using direct methods
  defp filter_to_ascii(input) do
    input
    |> String.to_charlist()
    |> Enum.filter(fn char -> char >= 0 and char <= 127 end)
    |> List.to_string()
  end

  # Trailing dots detection
  # Finds the start position and count of trailing dots in input
  # Returns {start_position, dots_count} or nil if no trailing dots found
  @spec find_trailing_dots_start(String.t()) :: {non_neg_integer(), non_neg_integer()} | nil
  defp find_trailing_dots_start(input) do
    # Work backwards from end to find start of trailing dots
    # Allow whitespace/newlines mixed with dots
    trimmed = String.trim_trailing(input)

    if trimmed == input do
      # No trailing whitespace, check for dots directly
      find_dots_at_end(input)
    else
      # Has trailing whitespace, check what's before it
      case find_dots_at_end(trimmed) do
        nil ->
          # No dots before whitespace
          nil

        {start_pos, dots_count} ->
          # Found dots, return position in original string
          {start_pos, dots_count}
      end
    end
  end

  # Find consecutive dots at the end of a string
  # Returns {start_position, count} or nil
  @spec find_dots_at_end(String.t()) :: {non_neg_integer(), non_neg_integer()} | nil
  defp find_dots_at_end(input) do
    graphemes = String.graphemes(input)
    len = length(graphemes)

    if len == 0 do
      nil
    else
      # Count dots from end, allowing mixed whitespace/newlines
      {dots_count, content_end_pos} = count_trailing_dots(Enum.reverse(graphemes), 0, 0, len)

      if dots_count > 0 do
        {content_end_pos, dots_count}
      else
        nil
      end
    end
  end

  # Count trailing dots (with possible whitespace/newlines interspersed)
  # Returns {dot_count, position_where_content_ends}
  @spec count_trailing_dots([String.t()], non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          {non_neg_integer(), non_neg_integer()}
  defp count_trailing_dots([], dots_count, _chars_scanned, len), do: {dots_count, len}

  defp count_trailing_dots([char | rest], dots_count, chars_scanned, len) do
    cond do
      char == "." ->
        # Found a dot
        count_trailing_dots(rest, dots_count + 1, chars_scanned + 1, len)

      char in [" ", "\t", "\n", "\r"] ->
        # Whitespace is allowed between dots in truncation pattern
        count_trailing_dots(rest, dots_count, chars_scanned + 1, len)

      true ->
        # Hit actual content - return what we found
        {dots_count, len - chars_scanned}
    end
  end
end
