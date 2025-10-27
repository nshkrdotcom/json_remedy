defmodule JsonRemedy.Layer3.HtmlHandlers do
  @moduledoc """
  Handles detection and quoting of unquoted HTML content in JSON values.

  This module detects HTML-like content that appears unquoted after colons
  in JSON and wraps it in quotes with proper escaping.
  """

  alias JsonRemedy.Layer3.SyntaxHelpers

  @doc """
  Check if the current position starts with HTML content.
  Returns true if it looks like HTML (starts with < followed by tag name or !DOCTYPE).
  """
  @spec is_html_start?(String.t(), non_neg_integer()) :: boolean()
  def is_html_start?(content, position) do
    remaining = String.slice(content, position..-1//1)

    cond do
      # Check for <!DOCTYPE
      String.starts_with?(remaining, "<!DOCTYPE") or
          String.starts_with?(remaining, "<!doctype") ->
        true

      # Check for <HTML> or <html>
      String.match?(remaining, ~r/^<[Hh][Tt][Mm][Ll][\s>]/) ->
        true

      # Check for other common HTML tags: <div>, <p>, <h1>, etc.
      String.match?(remaining, ~r/^<[A-Za-z][A-Za-z0-9]*[\s>\/]/) ->
        true

      true ->
        false
    end
  end

  @doc """
  Extract HTML content starting from position until we hit a JSON structural delimiter.
  Returns {html_content, chars_consumed, bytes_consumed}.

  Strategy: Track HTML tag depth. Only stop at JSON delimiters when:
  - We're at HTML tag depth 0 (all tags closed)
  - We're at JSON depth 0 (no nested JSON-like braces)
  - We're not inside an HTML tag marker (between < and >)
  """
  @spec extract_html_content(String.t(), non_neg_integer()) ::
          {String.t(), non_neg_integer(), non_neg_integer()}
  def extract_html_content(content, start_position) do
    extract_html_content_recursive(content, start_position, start_position, 0, 0, false)
  end

  defp finalize_html_result(content, start_pos, stop_pos) do
    length = stop_pos - start_pos
    raw_html = String.slice(content, start_pos, length)
    trimmed_html = String.trim_trailing(raw_html)

    chars_consumed = max(length, 0)
    bytes_consumed = if length <= 0, do: 0, else: byte_size(raw_html)

    {trimmed_html, chars_consumed, bytes_consumed}
  end

  # Helper to find end of HTML comment
  defp find_comment_end(content, start_pos) do
    case :binary.match(content, "-->", scope: {start_pos, byte_size(content) - start_pos}) do
      # Position after -->
      {pos, _len} -> pos + 3
      # End of content if no closing found
      :nomatch -> String.length(content)
    end
  end

  # Helper to find end of DOCTYPE declaration (find the closing >)
  defp find_doctype_end(content, start_pos) do
    case :binary.match(content, ">", scope: {start_pos, byte_size(content) - start_pos}) do
      # Position after >
      {pos, _len} -> pos + 1
      # End of content if no closing found
      :nomatch -> String.length(content)
    end
  end

  # HTML void elements that don't have closing tags
  @void_elements ~w(area base br col embed hr img input link meta param source track wbr)

  # Check if a tag is a void element by looking at the tag name after <
  defp is_void_element?(content, tag_start_pos) do
    # Extract tag name (characters after < until space or >)
    remaining = String.slice(content, tag_start_pos..-1//1)

    case Regex.run(~r/^<([a-zA-Z]+)[\s>\/]/, remaining) do
      [_, tag_name] -> String.downcase(tag_name) in @void_elements
      _ -> false
    end
  end

  # Recursively extract HTML until we hit a JSON delimiter
  # Tracks:
  # - json_depth: depth of JSON-like braces/brackets
  # - html_depth: depth of HTML tags (increments on <tag>, decrements on </tag>)
  # - inside_tag_marker: true when between < and >
  defp extract_html_content_recursive(
         content,
         current_pos,
         start_pos,
         json_depth,
         html_depth,
         inside_tag_marker
       ) do
    content_length = String.length(content)

    if current_pos >= content_length do
      # Reached end of content
      finalize_html_result(content, start_pos, content_length)
    else
      char = String.at(content, current_pos)

      next_char =
        if current_pos + 1 < String.length(content),
          do: String.at(content, current_pos + 1),
          else: nil

      cond do
        # HTML comment: <!-- ... -->
        char == "<" and String.slice(content, current_pos, 4) == "<!--" ->
          # Find the end of comment -->
          comment_end = find_comment_end(content, current_pos + 4)

          extract_html_content_recursive(
            content,
            comment_end,
            start_pos,
            json_depth,
            html_depth,
            false
          )

        # DOCTYPE declaration: <!DOCTYPE ... > (doesn't affect tag depth)
        char == "<" and String.slice(content, current_pos, 9) == "<!DOCTYPE" ->
          # Find the end of DOCTYPE declaration
          doctype_end = find_doctype_end(content, current_pos + 9)

          extract_html_content_recursive(
            content,
            doctype_end,
            start_pos,
            json_depth,
            html_depth,
            false
          )

        # Entering an HTML tag
        char == "<" and next_char == "/" ->
          # Closing tag: </tag>
          extract_html_content_recursive(
            content,
            current_pos + 1,
            start_pos,
            json_depth,
            html_depth - 1,
            true
          )

        char == "<" ->
          # Opening tag or self-closing: <tag> or <tag/>
          # Check if it's a void element that doesn't need closing
          is_void = is_void_element?(content, current_pos)
          depth_change = if is_void, do: 0, else: 1

          extract_html_content_recursive(
            content,
            current_pos + 1,
            start_pos,
            json_depth,
            html_depth + depth_change,
            true
          )

        char == ">" and inside_tag_marker ->
          # Leaving tag marker - check if this was a self-closing tag
          prev_char = if current_pos > 0, do: String.at(content, current_pos - 1), else: nil
          new_html_depth = if prev_char == "/", do: html_depth - 1, else: html_depth

          extract_html_content_recursive(
            content,
            current_pos + 1,
            start_pos,
            json_depth,
            new_html_depth,
            false
          )

        # Stop at JSON delimiters ONLY when all HTML tags are closed
        char in [",", "}", "]"] and json_depth == 0 and html_depth <= 0 and not inside_tag_marker ->
          finalize_html_result(content, start_pos, current_pos)

        # Track JSON-like depth (for data attributes with JSON)
        char == "{" and not inside_tag_marker ->
          extract_html_content_recursive(
            content,
            current_pos + 1,
            start_pos,
            json_depth + 1,
            html_depth,
            inside_tag_marker
          )

        char == "}" and json_depth > 0 and not inside_tag_marker ->
          extract_html_content_recursive(
            content,
            current_pos + 1,
            start_pos,
            json_depth - 1,
            html_depth,
            inside_tag_marker
          )

        char == "[" and not inside_tag_marker ->
          extract_html_content_recursive(
            content,
            current_pos + 1,
            start_pos,
            json_depth + 1,
            html_depth,
            inside_tag_marker
          )

        char == "]" and json_depth > 0 and not inside_tag_marker ->
          extract_html_content_recursive(
            content,
            current_pos + 1,
            start_pos,
            json_depth - 1,
            html_depth,
            inside_tag_marker
          )

        # Continue consuming
        true ->
          extract_html_content_recursive(
            content,
            current_pos + 1,
            start_pos,
            json_depth,
            html_depth,
            inside_tag_marker
          )
      end
    end
  end

  @doc """
  Process HTML content by wrapping it in quotes and escaping internal quotes and special characters.
  Returns {quoted_html, repairs}.
  """
  @spec quote_html_content(String.t(), non_neg_integer()) :: {String.t(), list()}
  def quote_html_content(html, position) do
    # Escape special characters for JSON strings
    escaped_html =
      html
      # Backslashes first
      |> String.replace("\\", "\\\\")
      # Double quotes
      |> String.replace("\"", "\\\"")
      # Newlines
      |> String.replace("\n", "\\n")
      # Carriage returns
      |> String.replace("\r", "\\r")
      # Tabs
      |> String.replace("\t", "\\t")

    # Wrap in double quotes
    quoted = "\"#{escaped_html}\""

    repair =
      SyntaxHelpers.create_repair(
        "quoted unquoted HTML value",
        "Wrapped unquoted HTML content in quotes",
        position
      )

    {quoted, [repair]}
  end

  @doc """
  Process HTML content for IO list version.
  Returns {html_iolist, chars_consumed, bytes_consumed, repairs}.
  """
  @spec process_html_iolist(String.t(), map()) ::
          {iodata(), non_neg_integer(), non_neg_integer(), list()}
  def process_html_iolist(content, state) do
    {html, chars_consumed, bytes_consumed} = extract_html_content(content, state.position)
    {quoted_html, repairs} = quote_html_content(html, state.position)

    {quoted_html, chars_consumed, bytes_consumed, repairs}
  end

  @doc """
  Process HTML content for regular string version.
  Returns {html_string, chars_consumed, bytes_consumed, repairs}.
  """
  @spec process_html_string(String.t(), map()) ::
          {String.t(), non_neg_integer(), non_neg_integer(), list()}
  def process_html_string(content, state) do
    {html, chars_consumed, bytes_consumed} = extract_html_content(content, state.position)
    {quoted_html, repairs} = quote_html_content(html, state.position)

    {quoted_html, chars_consumed, bytes_consumed, repairs}
  end
end
