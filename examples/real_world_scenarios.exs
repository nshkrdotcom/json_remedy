# Real-World Scenarios Examples for JsonRemedy
#
# This file demonstrates JsonRemedy handling realistic, problematic JSON
# commonly encountered in production environments.
#
# Run with: mix run examples/real_world_scenarios.exs

defmodule RealWorldExamples do
  @moduledoc """
  Real-world examples showing JsonRemedy fixing JSON from actual use cases:
  - LLM/AI model outputs
  - Legacy system exports
  - User input from web forms
  - Configuration files
  - API responses with formatting issues
  """

  alias JsonRemedy.Layer1.ContentCleaning
  alias JsonRemedy.Layer2.StructuralRepair
  alias JsonRemedy.Layer3.SyntaxNormalization
  alias JsonRemedy.Layer4.Validation

  def run_all_examples do
    IO.puts("=== JsonRemedy Real-World Scenarios ===\n")

    # Example 1: LLM/ChatGPT output with code fences
    example_1_llm_output()

    # Example 2: Legacy system export
    example_2_legacy_export()

    # Example 3: User form input
    example_3_user_input()

    # Example 4: Configuration file with comments
    example_4_config_file()

    # Example 5: API response with mixed quote styles
    example_5_api_response()

    # Example 6: Database dump with trailing commas
    example_6_database_dump()

    # Example 7: JavaScript object literal
    example_7_js_object()

    # Example 8: Malformed log output
    example_8_log_output()

    IO.puts("\n=== All real-world examples completed! ===")
  end

  defp example_1_llm_output do
    IO.puts("Example 1: LLM/ChatGPT Output with Code Fences")
    IO.puts("==============================================")

    malformed = ~s|Here's the user data you requested:

```json
{
  "users": [
    {name: "Alice Johnson", age: 32, role: "engineer"},
    {name: "Bob Smith", age: 28, role: "designer"},
    {name: "Carol Williams", age: 35, role: "manager"}
  ],
  "metadata": {
    generated_at: "2024-01-15",
    total_count: 3,
    active_only: True
  }
}
```

This data includes all active users in the system.|

    IO.puts("Input (LLM response with code fences and explanatory text):")
    IO.puts(malformed)
    IO.puts("")

    repair_json_pipeline(malformed, "LLM Output")
  end

  defp example_2_legacy_export do
    IO.puts("Example 2: Legacy System Export")
    IO.puts("==============================")

    malformed = ~s|# Legacy CRM Export - Generated 2024-01-15
# Format: JSON-like but not strictly compliant

{
  customer_id: 12345,
  name: 'ACME Corporation',
  contacts: [
    {name: 'John Doe', email: 'john@acme.com', phone: '555-0123'},
    {name: 'Jane Smith', email: 'jane@acme.com', phone: '555-0124',}
  ],
  address: {
    street: '123 Main St',
    city: 'Anytown',
    state: 'CA',
    # Postal code might be missing
    country: 'USA'
  },
  active: True,
  last_contact: None,
  notes: 'Important client - handle with care'
  # Missing final brace due to export truncation|

    IO.puts("Input (Legacy system export with comments and mixed syntax):")
    IO.puts(malformed)
    IO.puts("")

    repair_json_pipeline(malformed, "Legacy Export")
  end

  defp example_3_user_input do
    IO.puts("Example 3: User Form Input")
    IO.puts("=========================")

    malformed = ~s|{
  'firstName': 'Sarah',
  'lastName': 'Connor',
  preferences: {
    theme: 'dark',
    notifications: True,
    language: 'en-US',
    timezone: 'America/Los_Angeles'
  },
  'contactInfo': {
    email: 'sarah.connor@resistance.com',
    phone: '+1-555-FUTURE',
    'emergencyContact': 'Kyle Reese'
  },|

    IO.puts("Input (User form data with mixed quotes and missing closing brace):")
    IO.puts(malformed)
    IO.puts("")

    repair_json_pipeline(malformed, "User Input")
  end

  defp example_4_config_file do
    IO.puts("Example 4: Configuration File with Comments")
    IO.puts("==========================================")

    malformed = ~s|{
  // Database configuration
  "database": {
    host: "localhost",
    port: 5432,
    name: "production_db",
    ssl: True,
    // Connection pool settings
    pool_size: 20,
    timeout: 5000
  },

  // Redis cache settings
  "cache": {
    redis_url: "redis://localhost:6379/0",
    ttl: 3600,
    prefix: "myapp:",
  },

  // Feature flags
  features: {
    new_ui: True,
    beta_features: False,
    analytics: True,
    // Experimental features
    ai_assistance: False,
  }

  // API configuration
  // "api": {
  //   rate_limit: 1000,
  //   timeout: 30
  // }
}|

    IO.puts("Input (Config file with comments and mixed syntax):")
    IO.puts(malformed)
    IO.puts("")

    repair_json_pipeline(malformed, "Config File")
  end

  defp example_5_api_response do
    IO.puts("Example 5: API Response with Mixed Quote Styles")
    IO.puts("===============================================")

    malformed = ~s|{
  'status': 'success',
  "data": {
    users: [
      {"id": 1, name: 'Alice', "email": 'alice@example.com', active: True},
      {"id": 2, name: 'Bob', "email": 'bob@example.com', active: False},
      {"id": 3, name: 'Charlie', "email": 'charlie@example.com', active: True,}
    ],
    'pagination': {
      "page": 1,
      per_page: 10,
      'total': 3,
      "has_more": False
    }
  },
  "meta": {
    generated_at: '2024-01-15T10:30:00Z',
    'api_version': "v2.1",
    request_id: '550e8400-e29b-41d4-a716-446655440000'
  }|

    IO.puts("Input (API response with mixed quote styles):")
    IO.puts(malformed)
    IO.puts("")

    repair_json_pipeline(malformed, "API Response")
  end

  defp example_6_database_dump do
    IO.puts("Example 6: Database Dump with Trailing Commas")
    IO.puts("=============================================")

    malformed = ~s|{
  "table": "products",
  "exported_at": "2024-01-15T09:00:00Z",
  "records": [
    {
      "id": 1,
      "name": "Laptop Computer",
      "price": 999.99,
      "category": "Electronics",
      "in_stock": true,
      "tags": ["laptop", "computer", "portable",],
      "specifications": {
        "cpu": "Intel i7",
        "ram": "16GB",
        "storage": "512GB SSD",
        "display": "15.6 inch",
      },
    },
    {
      "id": 2,
      "name": "Wireless Mouse",
      "price": 29.99,
      "category": "Accessories",
      "in_stock": true,
      "tags": ["mouse", "wireless", "ergonomic",],
      "specifications": {
        "connection": "Bluetooth",
        "battery_life": "6 months",
        "dpi": 1600,
      },
    },
  ],
  "total_records": 2,
}|

    IO.puts("Input (Database dump with trailing commas):")
    IO.puts(malformed)
    IO.puts("")

    repair_json_pipeline(malformed, "Database Dump")
  end

  defp example_7_js_object do
    IO.puts("Example 7: JavaScript Object Literal")
    IO.puts("====================================")

    malformed = ~s|// Frontend configuration object
const config = {
  apiEndpoint: 'https://api.example.com/v1',
  timeout: 5000,
  retries: 3,
  features: {
    darkMode: true,
    notifications: true,
    autoSave: false,
  },
  user: {
    defaultLanguage: 'en',
    timezone: 'UTC',
    preferences: {
      theme: 'auto',
      sidebar: 'collapsed',
      itemsPerPage: 25,
    }
  },
  // Debug settings
  debug: {
    enabled: false,
    logLevel: 'info',
    endpoints: ['api', 'auth', 'websocket',]
  }
};

// Export for use in other modules
export default config;|

    IO.puts("Input (JavaScript object literal with extra syntax):")
    IO.puts(malformed)
    IO.puts("")

    repair_json_pipeline(malformed, "JavaScript Object")
  end

  defp example_8_log_output do
    IO.puts("Example 8: Malformed Log Output")
    IO.puts("===============================")

    malformed = ~s|[2024-01-15 14:30:22] INFO: Request processed successfully
{
  timestamp: '2024-01-15T14:30:22.123Z',
  level: 'INFO',
  message: 'User authentication successful',
  user_id: 12345,
  session_id: 'abc123def456',
  ip_address: '192.168.1.100',
  user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  request: {
    method: 'POST',
    url: '/api/auth/login',
    headers: {
      'content-type': 'application/json',
      'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    },
    body_size: 156,
  },
  response: {
    status: 200,
    duration_ms: 45,
    body_size: 234,
  },
  // Additional context
  context: {
    feature_flags: ['new_auth', 'security_headers', 'rate_limiting',],
    experiments: ['ab_test_login_flow'],
    environment: 'production'
  }
[2024-01-15 14:30:22] DEBUG: Session created for user 12345|

    IO.puts("Input (Log output with embedded JSON and extra text):")
    IO.puts(malformed)
    IO.puts("")

    repair_json_pipeline(malformed, "Log Output")
  end

  # Helper function to run the full repair pipeline
  defp repair_json_pipeline(malformed_json, example_name) do
    context = %{repairs: [], options: []}

    IO.puts("Processing #{example_name} through JsonRemedy pipeline...")
    IO.puts("")

    # Layer 1: Content Cleaning
    {output, context} = case ContentCleaning.process(malformed_json, context) do
      {:ok, repaired, updated_context} ->
        repairs_applied = length(updated_context.repairs) - length(context.repairs)
        if repairs_applied > 0 do
          IO.puts("✓ Layer 1 (Content Cleaning): Applied #{repairs_applied} repairs")
        else
          IO.puts("- Layer 1 (Content Cleaning): No changes needed")
        end
        {repaired, updated_context}
      {:error, reason} ->
        IO.puts("✗ Layer 1 (Content Cleaning): Error - #{reason}")
        {malformed_json, context}
    end

    # Layer 2: Structural Repair
    {output, context} = case StructuralRepair.process(output, context) do
      {:ok, repaired, updated_context} ->
        repairs_applied = length(updated_context.repairs) - length(context.repairs)
        if repairs_applied > 0 do
          IO.puts("✓ Layer 2 (Structural Repair): Applied #{repairs_applied} repairs")
        else
          IO.puts("- Layer 2 (Structural Repair): No changes needed")
        end
        {repaired, updated_context}
      {:error, reason} ->
        IO.puts("✗ Layer 2 (Structural Repair): Error - #{reason}")
        {output, context}
    end

    # Layer 3: Syntax Normalization
    {output, context} = case SyntaxNormalization.process(output, context) do
      {:ok, repaired, updated_context} ->
        repairs_applied = length(updated_context.repairs) - length(context.repairs)
        if repairs_applied > 0 do
          IO.puts("✓ Layer 3 (Syntax Normalization): Applied #{repairs_applied} repairs")
        else
          IO.puts("- Layer 3 (Syntax Normalization): No changes needed")
        end
        {repaired, updated_context}
      {:error, reason} ->
        IO.puts("✗ Layer 3 (Syntax Normalization): Error - #{reason}")
        {output, context}
    end

    # Layer 4: Validation
    case Validation.process(output, context) do
      {:ok, parsed, final_context} ->
        IO.puts("✓ Layer 4 (Validation): SUCCESS - Valid JSON produced!")
        IO.puts("")

        IO.puts("Final repaired JSON:")
        IO.puts("-------------------")
        repaired_json = Jason.encode!(parsed, pretty: true)
        IO.puts(repaired_json)
        IO.puts("")

        if length(final_context.repairs) > 0 do
          IO.puts("Total repairs applied: #{length(final_context.repairs)}")
          IO.puts("Repair summary:")
          for {repair, index} <- Enum.with_index(final_context.repairs, 1) do
            IO.puts("  #{index}. #{repair.action}")
          end
        else
          IO.puts("No repairs were needed - JSON was already valid!")
        end

        IO.puts("")

      {:continue, output, _} ->
        IO.puts("✗ Layer 4 (Validation): Could not produce valid JSON")
        IO.puts("Note: This would normally pass to Layer 5 (Tolerant Parsing) when implemented")
        IO.puts("Final output: #{String.slice(output, 0, 200)}...")
        IO.puts("")
      {:error, reason} ->
        IO.puts("✗ Layer 4 (Validation): Error occurred - #{reason}")
        IO.puts("Final output: #{String.slice(output, 0, 200)}...")
        IO.puts("")
    end

    IO.puts(String.duplicate("=", 80))
    IO.puts("")
  end
end

# Run the examples
RealWorldExamples.run_all_examples()
