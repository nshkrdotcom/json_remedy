defmodule JsonRemedy.Context.ContextValuesTest do
  use ExUnit.Case, async: true
  alias JsonRemedy.Context.ContextValues

  describe "valid_context_values/0" do
    test "returns all valid context values" do
      values = ContextValues.valid_context_values()

      assert :root in values
      assert :object_key in values
      assert :object_value in values
      assert :array in values
      assert length(values) == 4
    end
  end

  describe "valid_context?/1" do
    test "returns true for valid contexts" do
      assert ContextValues.valid_context?(:root) == true
      assert ContextValues.valid_context?(:object_key) == true
      assert ContextValues.valid_context?(:object_value) == true
      assert ContextValues.valid_context?(:array) == true
    end

    test "returns false for invalid contexts" do
      assert ContextValues.valid_context?(:invalid) == false
      assert ContextValues.valid_context?(:foo) == false
      assert ContextValues.valid_context?(nil) == false
      assert ContextValues.valid_context?("string") == false
    end
  end

  describe "can_transition_to?/2" do
    test "allows valid transitions from root" do
      assert ContextValues.can_transition_to?(:root, :object_key) == true
      assert ContextValues.can_transition_to?(:root, :array) == true
    end

    test "disallows invalid transitions from root" do
      assert ContextValues.can_transition_to?(:root, :object_value) == false
      assert ContextValues.can_transition_to?(:root, :root) == false
    end

    test "allows valid transitions from object_key" do
      assert ContextValues.can_transition_to?(:object_key, :object_value) == true
      assert ContextValues.can_transition_to?(:object_key, :object_key) == true
      assert ContextValues.can_transition_to?(:object_key, :array) == true
    end

    test "allows valid transitions from object_value" do
      assert ContextValues.can_transition_to?(:object_value, :object_key) == true
      assert ContextValues.can_transition_to?(:object_value, :object_value) == true
      assert ContextValues.can_transition_to?(:object_value, :array) == true
    end

    test "allows valid transitions from array" do
      assert ContextValues.can_transition_to?(:array, :object_key) == true
      assert ContextValues.can_transition_to?(:array, :array) == true
      assert ContextValues.can_transition_to?(:array, :object_value) == true
    end

    test "handles invalid source contexts" do
      assert ContextValues.can_transition_to?(:invalid, :object_key) == false
      assert ContextValues.can_transition_to?(nil, :array) == false
    end

    test "handles invalid target contexts" do
      assert ContextValues.can_transition_to?(:root, :invalid) == false
      assert ContextValues.can_transition_to?(:object_key, nil) == false
    end
  end

  describe "next_expected_context/2" do
    test "predicts next context for object key" do
      assert ContextValues.next_expected_context(:object_key, ":") == :object_value
      assert ContextValues.next_expected_context(:object_key, "=") == :object_value
      assert ContextValues.next_expected_context(:object_key, ",") == :object_key
    end

    test "predicts next context for object value" do
      assert ContextValues.next_expected_context(:object_value, ",") == :object_key
      assert ContextValues.next_expected_context(:object_value, "}") == :pop_context
    end

    test "predicts next context for array" do
      assert ContextValues.next_expected_context(:array, ",") == :array
      assert ContextValues.next_expected_context(:array, "]") == :pop_context
    end

    test "handles unknown characters" do
      assert ContextValues.next_expected_context(:object_key, "x") == :object_key
      assert ContextValues.next_expected_context(:array, "z") == :array
    end
  end

  describe "context_allows_repair?/2" do
    test "object key context allows key-related repairs" do
      assert ContextValues.context_allows_repair?(:object_key, :quote_normalization) == true
      assert ContextValues.context_allows_repair?(:object_key, :unquoted_keys) == true
      assert ContextValues.context_allows_repair?(:object_key, :colon_fix) == true
    end

    test "object key context disallows value-related repairs" do
      assert ContextValues.context_allows_repair?(:object_key, :boolean_normalization) == false
      assert ContextValues.context_allows_repair?(:object_key, :null_normalization) == false
    end

    test "object value context allows value-related repairs" do
      assert ContextValues.context_allows_repair?(:object_value, :boolean_normalization) == true
      assert ContextValues.context_allows_repair?(:object_value, :null_normalization) == true
      assert ContextValues.context_allows_repair?(:object_value, :quote_normalization) == true
    end

    test "array context allows array-related repairs" do
      assert ContextValues.context_allows_repair?(:array, :comma_fix) == true
      assert ContextValues.context_allows_repair?(:array, :bracket_fix) == true
      assert ContextValues.context_allows_repair?(:array, :boolean_normalization) == true
    end

    test "root context allows structural repairs" do
      assert ContextValues.context_allows_repair?(:root, :brace_fix) == true
      assert ContextValues.context_allows_repair?(:root, :bracket_fix) == true
      assert ContextValues.context_allows_repair?(:root, :comment_removal) == true
    end
  end

  describe "get_repair_priority/2" do
    test "returns higher priority for context-specific repairs" do
      # Object key context prioritizes key repairs
      assert ContextValues.get_repair_priority(:object_key, :unquoted_keys) >
               ContextValues.get_repair_priority(:object_key, :boolean_normalization)

      # Object value context prioritizes value repairs
      assert ContextValues.get_repair_priority(:object_value, :boolean_normalization) >
               ContextValues.get_repair_priority(:object_value, :unquoted_keys)
    end

    test "returns base priority for unknown repairs" do
      assert ContextValues.get_repair_priority(:object_key, :unknown_repair) == 50
      assert ContextValues.get_repair_priority(:invalid_context, :quote_normalization) == 50
    end
  end
end
