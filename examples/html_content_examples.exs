# HTML Content Examples for JsonRemedy
#
# This file demonstrates JsonRemedy's ability to handle unquoted HTML content
# in JSON values, a common issue when API error pages are returned instead of JSON.
#
# Run with: mix run examples/html_content_examples.exs

defmodule HtmlContentExamples do
  @moduledoc """
  Real-world examples showing JsonRemedy fixing JSON with embedded HTML content:
  - API error responses (503, 404, 500 pages)
  - HTML fragments in JSON values
  - DOCTYPE declarations
  - Complex nested HTML structures
  """

  def run_all_examples do
    IO.puts("=== JsonRemedy HTML Content Examples ===\n")

    # Example 1: API 503 Service Unavailable error page
    example_1_api_503_error()

    # Example 2: API 404 Not Found error page
    example_2_api_404_error()

    # Example 3: Simple HTML fragment in response
    example_3_html_fragment()

    # Example 4: Multiple HTML values in array
    example_4_multiple_html_values()

    # Example 5: Complex nested HTML with JSON-like content
    example_5_complex_nested_html()

    IO.puts("\n=== All HTML content examples completed! ===")
  end

  defp example_1_api_503_error do
    IO.puts("Example 1: API 503 Service Unavailable Error Page")
    IO.puts("=================================================")

    malformed = """
    {
        "responses": [
            {
                "id": "33",
                "status": 503,
                "headers": {
                    "Content-Type": "text/html; charset=us-ascii"
                },
                "body":<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN""http://www.w3.org/TR/html4/strict.dtd">
    <HTML><HEAD><TITLE>Service Unavailable</TITLE>
    <META HTTP-EQUIV="Content-Type" Content="text/html; charset=us-ascii"></HEAD>
    <BODY><h2>Service Unavailable</h2>
    <hr><p>HTTP Error 503. The service is unavailable.</p>
    </BODY></HTML>
            }
        ]
    }
    """

    IO.puts("Input (API response with unquoted HTML error page):")
    IO.puts(String.slice(malformed, 0, 200) <> "...")
    IO.puts("")

    case JsonRemedy.repair(malformed) do
      {:ok, result} ->
        IO.puts("✓ Successfully repaired!")
        IO.puts("\nParsed structure:")
        IO.inspect(result, pretty: true, limit: :infinity)

        # Show the HTML body was properly captured
        html_body = get_in(result, ["responses", Access.at(0), "body"])
        IO.puts("\n✓ HTML body properly extracted and quoted:")
        IO.puts(String.slice(html_body, 0, 100) <> "...")

      {:error, reason} ->
        IO.puts("✗ Failed to repair: #{reason}")
    end

    IO.puts("\n" <> String.duplicate("-", 80) <> "\n")
  end

  defp example_2_api_404_error do
    IO.puts("Example 2: API 404 Not Found Error Page")
    IO.puts("========================================")

    malformed = """
    {
        "request_id": "abc-123",
        "timestamp": "2025-10-24T10:30:00Z",
        "error": {
            "code": 404,
            "message": "Resource not found",
            "details":<!DOCTYPE html>
    <html>
    <head><title>404 Not Found</title></head>
    <body>
    <h1>Not Found</h1>
    <p>The requested URL was not found on this server.</p>
    <!-- Server: nginx/1.18.0 -->
    </body>
    </html>
        }
    }
    """

    IO.puts("Input (API error with HTML 404 page):")
    IO.puts(String.slice(malformed, 0, 150) <> "...")
    IO.puts("")

    case JsonRemedy.repair(malformed) do
      {:ok, result} ->
        IO.puts("✓ Successfully repaired!")
        IO.puts("\nError details structure:")
        IO.inspect(get_in(result, ["error"]), pretty: true)

      {:error, reason} ->
        IO.puts("✗ Failed to repair: #{reason}")
    end

    IO.puts("\n" <> String.duplicate("-", 80) <> "\n")
  end

  defp example_3_html_fragment do
    IO.puts("Example 3: Simple HTML Fragment in Response")
    IO.puts("===========================================")

    malformed = """
    {
        "user_id": "12345",
        "bio":<div class="user-bio">
    <p>Software engineer interested in <strong>Elixir</strong> and <em>functional programming</em>.</p>
    <br/>
    <p>Find me on GitHub!</p>
    </div>,
        "verified": true
    }
    """

    IO.puts("Input (JSON with unquoted HTML fragment):")
    IO.puts(malformed)
    IO.puts("")

    case JsonRemedy.repair(malformed) do
      {:ok, result} ->
        IO.puts("✓ Successfully repaired!")
        IO.puts("\nParsed user data:")
        IO.inspect(result, pretty: true)

      {:error, reason} ->
        IO.puts("✗ Failed to repair: #{reason}")
    end

    IO.puts("\n" <> String.duplicate("-", 80) <> "\n")
  end

  defp example_4_multiple_html_values do
    IO.puts("Example 4: Multiple HTML Values in Array")
    IO.puts("=========================================")

    malformed = """
    {
        "templates": [
            {
                "name": "header",
                "content":<header><h1>Welcome</h1></header>
            },
            {
                "name": "footer",
                "content":<footer><p>&copy; 2025 Company</p></footer>
            }
        ]
    }
    """

    IO.puts("Input (array with multiple unquoted HTML values):")
    IO.puts(malformed)
    IO.puts("")

    case JsonRemedy.repair(malformed) do
      {:ok, result} ->
        IO.puts("✓ Successfully repaired!")
        IO.puts("\nParsed templates:")
        IO.inspect(result, pretty: true)

      {:error, reason} ->
        IO.puts("✗ Failed to repair: #{reason}")
    end

    IO.puts("\n" <> String.duplicate("-", 80) <> "\n")
  end

  defp example_5_complex_nested_html do
    IO.puts("Example 5: Complex Nested HTML with JSON-like Content")
    IO.puts("======================================================")

    malformed = """
    {
        "page_data": {
            "title": "Dashboard",
            "rendered_html":<div class="dashboard" data-config='{"theme":"dark","refresh":30}'>
    <section id="stats">
        <div class="stat-card">
            <h3>Active Users</h3>
            <p class="value">1,234</p>
        </div>
        <!-- More stats here -->
    </section>
    <script type="text/javascript">
        console.log("Dashboard loaded");
    </script>
    </div>,
            "metadata": {
                "generated_at": "2025-10-24",
                "version": "2.0"
            }
        }
    }
    """

    IO.puts("Input (complex HTML with nested JSON-like attributes):")
    IO.puts(String.slice(malformed, 0, 200) <> "...")
    IO.puts("")

    case JsonRemedy.repair(malformed) do
      {:ok, result} ->
        IO.puts("✓ Successfully repaired!")
        IO.puts("\nParsed page data structure:")
        page_data = result["page_data"]
        IO.puts("Title: #{page_data["title"]}")
        IO.puts("Metadata: #{inspect(page_data["metadata"])}")
        IO.puts("\nRendered HTML (first 150 chars):")
        html = page_data["rendered_html"]
        IO.puts(String.slice(html, 0, 150) <> "...")

      {:error, reason} ->
        IO.puts("✗ Failed to repair: #{reason}")
    end

    IO.puts("\n" <> String.duplicate("-", 80) <> "\n")
  end
end

# Run all examples
HtmlContentExamples.run_all_examples()
