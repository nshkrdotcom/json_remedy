defmodule JsonRemedy.Integration.ContextIntegrationTest do
  use ExUnit.Case, async: true

  alias JsonRemedy.Context.{ContextValues, JsonContext}
  alias JsonRemedy.LayerBehaviour

  @moduletag :integration

  describe "context state preservation" do
    test "context survives basic operations" do
      context = JsonContext.new()

      # Push some contexts
      context = JsonContext.push_context(context, :object_key)
      context = JsonContext.push_context(context, :array)
      context = JsonContext.update_position(context, 10)

      # Verify state
      assert context.current == :array
      assert context.stack == [:object_key, :root]
      assert context.position == 10

      # Pop back
      context = JsonContext.pop_context(context)
      assert context.current == :object_key
      assert context.stack == [:root]
    end

    test "string context handling" do
      context =
        JsonContext.new()
        |> JsonContext.push_context(:object_value)
        |> JsonContext.update_position(5)
        |> JsonContext.enter_string("\"")

      # In string - most repairs should be blocked
      assert JsonContext.can_apply_repair?(context, :quote_normalization) == false
      assert JsonContext.can_apply_repair?(context, :boolean_normalization) == false
      assert JsonContext.can_apply_repair?(context, :comma_fix) == false

      # But string delimiter repairs allowed
      assert JsonContext.can_apply_repair?(context, :string_delimiter) == true

      # Exit string
      context = JsonContext.exit_string(context)

      # Now repairs allowed again
      assert JsonContext.can_apply_repair?(context, :quote_normalization) == true
      assert JsonContext.can_apply_repair?(context, :boolean_normalization) == true
    end
  end

  describe "context-aware repair decisions" do
    test "context values determine repair allowability" do
      # Object key context
      assert ContextValues.context_allows_repair?(:object_key, :unquoted_keys) == true
      assert ContextValues.context_allows_repair?(:object_key, :boolean_normalization) == false

      # Object value context
      assert ContextValues.context_allows_repair?(:object_value, :boolean_normalization) == true
      assert ContextValues.context_allows_repair?(:object_value, :unquoted_keys) == false

      # Array context
      assert ContextValues.context_allows_repair?(:array, :comma_fix) == true
      assert ContextValues.context_allows_repair?(:array, :colon_fix) == false
    end

    test "repair priorities are context-specific" do
      # Object key prioritizes key-related repairs
      key_priority = ContextValues.get_repair_priority(:object_key, :unquoted_keys)
      key_bool_priority = ContextValues.get_repair_priority(:object_key, :boolean_normalization)
      assert key_priority > key_bool_priority

      # Object value prioritizes value-related repairs
      value_priority = ContextValues.get_repair_priority(:object_value, :boolean_normalization)
      value_key_priority = ContextValues.get_repair_priority(:object_value, :unquoted_keys)
      assert value_priority > value_key_priority
    end
  end

  describe "context transitions" do
    test "valid transitions work correctly" do
      assert ContextValues.can_transition_to?(:root, :object_key) == true
      assert ContextValues.can_transition_to?(:object_key, :object_value) == true
      assert ContextValues.can_transition_to?(:object_value, :object_key) == true
      assert ContextValues.can_transition_to?(:array, :object_key) == true
    end

    test "invalid transitions are blocked" do
      assert ContextValues.can_transition_to?(:root, :object_value) == false
      assert ContextValues.can_transition_to?(:invalid, :object_key) == false
      assert ContextValues.can_transition_to?(:object_key, :invalid) == false
    end

    test "context prediction works for common characters" do
      assert ContextValues.next_expected_context(:object_key, ":") == :object_value
      assert ContextValues.next_expected_context(:object_value, ",") == :object_key
      assert ContextValues.next_expected_context(:object_value, "}") == :pop_context
      assert ContextValues.next_expected_context(:array, "]") == :pop_context
    end
  end

  describe "integration with LayerBehaviour" do
    test "LayerBehaviour.inside_string? still works" do
      # Test the existing function works
      assert LayerBehaviour.inside_string?("\"hello world\"", 5) == true
      assert LayerBehaviour.inside_string?("\"hello world\"", 0) == false
      assert LayerBehaviour.inside_string?("\"hello world\"", 13) == false
    end

    test "context system complements existing string detection" do
      context =
        JsonContext.new()
        |> JsonContext.enter_string("\"")

      # Both should agree when in string
      assert JsonContext.in_string?(context) == true
      assert LayerBehaviour.inside_string?("\"test", 1) == true
    end
  end

  describe "context system robustness" do
    test "handles deep nesting" do
      context = JsonContext.new()

      # Build deep nesting
      context =
        Enum.reduce(1..10, context, fn _i, acc ->
          acc
          |> JsonContext.push_context(:object_key)
          |> JsonContext.push_context(:array)
        end)

      assert JsonContext.context_stack_depth(context) == 20

      # Unwind it
      context =
        Enum.reduce(1..20, context, fn _i, acc ->
          JsonContext.pop_context(acc)
        end)

      assert context.current == :root
      assert JsonContext.context_stack_depth(context) == 0
    end

    test "gracefully handles edge cases" do
      context = JsonContext.new()

      # Pop from empty stack
      popped = JsonContext.pop_context(context)
      assert popped.current == :root
      assert popped.stack == []

      # Exit string when not in string
      exited = JsonContext.exit_string(context)
      assert exited.in_string == false
      assert exited.string_delimiter == nil
    end
  end

  describe "real-world scenarios" do
    test "object parsing context flow" do
      # Simulate parsing: {"key": "value", "key2": 42}
      context =
        JsonContext.new()
        # {
        |> JsonContext.push_context(:object_key)
        |> JsonContext.update_position(1)

      # At key position
      assert context.current == :object_key
      assert ContextValues.context_allows_repair?(context.current, :unquoted_keys) == true

      # Transition to value
      context = JsonContext.transition_context(context, :object_value)
      assert context.current == :object_value
      assert ContextValues.context_allows_repair?(context.current, :boolean_normalization) == true

      # Back to next key
      context = JsonContext.transition_context(context, :object_key)
      assert context.current == :object_key
    end

    test "array parsing context flow" do
      # Simulate parsing: [1, "string", true]
      context =
        JsonContext.new()
        |> JsonContext.push_context(:array)
        |> JsonContext.update_position(1)

      assert context.current == :array
      assert ContextValues.context_allows_repair?(context.current, :comma_fix) == true
      assert ContextValues.context_allows_repair?(context.current, :boolean_normalization) == true

      # String in array
      string_context = JsonContext.enter_string(context, "\"")
      assert JsonContext.can_apply_repair?(string_context, :boolean_normalization) == false

      # Exit string
      exit_context = JsonContext.exit_string(string_context)
      assert JsonContext.can_apply_repair?(exit_context, :boolean_normalization) == true
    end
  end
end
