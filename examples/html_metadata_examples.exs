# HTML Metadata Examples for JsonRemedy
#
# Demonstrates the new metadata returned by HtmlHandlers.extract_html_content/2
# so that consumers can rely on both grapheme and byte measurements.
#
# Run with: mix run examples/html_metadata_examples.exs

defmodule HtmlMetadataExamples do
  @moduledoc """
  Shows how to inspect the grapheme and byte counts returned when JsonRemedy
  wraps unquoted HTML fragments. Useful when integrating with systems that need
  byte-accurate slicing (e.g., Windows CRLF payloads or emoji-rich HTML).
  """

  alias JsonRemedy.Layer3.HtmlHandlers

  def run_all_examples do
    IO.puts("=== JsonRemedy HTML Metadata Examples ===\n")

    example_1_multibyte_html_metadata()
    example_2_offset_html_metadata()

    IO.puts("\n=== Completed HTML metadata examples! ===")
  end

  defp example_1_multibyte_html_metadata do
    IO.puts("Example 1: Metadata for multi-byte HTML fragment")
    IO.puts("==============================================")

    fragment = "<div>café 🚀</div>,\"next\""

    {html, graphemes, bytes} = HtmlHandlers.extract_html_content(fragment, 0)

    IO.puts("Extracted HTML: #{html}")
    IO.puts("Graphemes consumed: #{graphemes}")
    IO.puts("Bytes consumed: #{bytes}")
    IO.puts("Byte/Grapheme delta: #{bytes - graphemes}")
    IO.puts("\n" <> String.duplicate("-", 80) <> "\n")
  end

  defp example_2_offset_html_metadata do
    IO.puts("Example 2: Metadata from non-zero starting offset")
    IO.puts("===============================================")

    payload = ~s({"body":<section data-info="café 🚀">Line</section>,"ok":true})
    start_position = String.length(~s({"body":))

    {html, graphemes, bytes} = HtmlHandlers.extract_html_content(payload, start_position)

    IO.puts("Extracted HTML: #{html}")
    IO.puts("Graphemes consumed from offset #{start_position}: #{graphemes}")
    IO.puts("Bytes consumed from offset #{start_position}: #{bytes}")
    IO.puts("\n" <> String.duplicate("-", 80) <> "\n")
  end
end

HtmlMetadataExamples.run_all_examples()
