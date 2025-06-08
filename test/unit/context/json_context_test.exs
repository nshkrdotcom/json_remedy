defmodule JsonRemedy.Context.JsonContextTest do
  use ExUnit.Case, async: true
  alias JsonRemedy.Context.JsonContext

  describe "new/0" do
    test "creates empty context with default values" do
      context = JsonContext.new()

      assert context.current == :root
      assert context.stack == []
      assert context.position == 0
      assert context.in_string == false
      assert context.string_delimiter == nil
    end
  end

  describe "push_context/2" do
    test "pushes object context onto stack" do
      context = JsonContext.new()

      new_context = JsonContext.push_context(context, :object_key)

      assert new_context.current == :object_key
      assert new_context.stack == [:root]
    end

    test "pushes array context onto stack" do
      context = JsonContext.new()

      new_context = JsonContext.push_context(context, :array)

      assert new_context.current == :array
      assert new_context.stack == [:root]
    end

    test "maintains position and string state" do
      context = %JsonContext{
        current: :root,
        stack: [],
        position: 10,
        in_string: true,
        string_delimiter: "\""
      }

      new_context = JsonContext.push_context(context, :object_value)

      assert new_context.position == 10
      assert new_context.in_string == true
      assert new_context.string_delimiter == "\""
    end
  end

  describe "pop_context/1" do
    test "pops context from stack" do
      context = %JsonContext{
        current: :object_key,
        stack: [:root],
        position: 5,
        in_string: false,
        string_delimiter: nil
      }

      new_context = JsonContext.pop_context(context)

      assert new_context.current == :root
      assert new_context.stack == []
    end

    test "handles empty stack gracefully" do
      context = JsonContext.new()

      new_context = JsonContext.pop_context(context)

      assert new_context.current == :root
      assert new_context.stack == []
    end
  end

  describe "enter_string/2" do
    test "enters string context with delimiter" do
      context = JsonContext.new()

      new_context = JsonContext.enter_string(context, "\"")

      assert new_context.in_string == true
      assert new_context.string_delimiter == "\""
    end

    test "handles single quote delimiter" do
      context = JsonContext.new()

      new_context = JsonContext.enter_string(context, "'")

      assert new_context.in_string == true
      assert new_context.string_delimiter == "'"
    end
  end

  describe "exit_string/1" do
    test "exits string context" do
      context = %JsonContext{
        current: :object_value,
        stack: [:root],
        position: 5,
        in_string: true,
        string_delimiter: "\""
      }

      new_context = JsonContext.exit_string(context)

      assert new_context.in_string == false
      assert new_context.string_delimiter == nil
    end
  end

  describe "update_position/2" do
    test "updates position" do
      context = JsonContext.new()

      new_context = JsonContext.update_position(context, 15)

      assert new_context.position == 15
    end

    test "preserves other fields" do
      context = %JsonContext{
        current: :array,
        stack: [:root],
        position: 5,
        in_string: true,
        string_delimiter: "\""
      }

      new_context = JsonContext.update_position(context, 20)

      assert new_context.position == 20
      assert new_context.current == :array
      assert new_context.stack == [:root]
      assert new_context.in_string == true
      assert new_context.string_delimiter == "\""
    end
  end

  describe "transition_context/2" do
    test "transitions from object_key to object_value" do
      context = %JsonContext{
        current: :object_key,
        stack: [:root],
        position: 5,
        in_string: false,
        string_delimiter: nil
      }

      new_context = JsonContext.transition_context(context, :object_value)

      assert new_context.current == :object_value
      assert new_context.stack == [:root]
    end

    test "transitions from object_value to object_key" do
      context = %JsonContext{
        current: :object_value,
        stack: [:root],
        position: 10,
        in_string: false,
        string_delimiter: nil
      }

      new_context = JsonContext.transition_context(context, :object_key)

      assert new_context.current == :object_key
      assert new_context.stack == [:root]
    end
  end

  describe "is_in_string?/1" do
    test "returns true when in string" do
      context = %JsonContext{
        current: :object_value,
        stack: [:root],
        position: 5,
        in_string: true,
        string_delimiter: "\""
      }

      assert JsonContext.is_in_string?(context) == true
    end

    test "returns false when not in string" do
      context = JsonContext.new()

      assert JsonContext.is_in_string?(context) == false
    end
  end

  describe "context_stack_depth/1" do
    test "returns correct depth for empty stack" do
      context = JsonContext.new()

      assert JsonContext.context_stack_depth(context) == 0
    end

    test "returns correct depth for nested contexts" do
      context = %JsonContext{
        current: :object_value,
        stack: [:root, :array, :object_key],
        position: 5,
        in_string: false,
        string_delimiter: nil
      }

      assert JsonContext.context_stack_depth(context) == 3
    end
  end

  describe "can_apply_repair?/2" do
    test "allows repair when not in string" do
      context = JsonContext.new()

      assert JsonContext.can_apply_repair?(context, :quote_normalization) == true
    end

    test "prevents repair when in string for most repair types" do
      context = %JsonContext{
        current: :object_value,
        stack: [:root],
        position: 5,
        in_string: true,
        string_delimiter: "\""
      }

      assert JsonContext.can_apply_repair?(context, :quote_normalization) == false
      assert JsonContext.can_apply_repair?(context, :boolean_normalization) == false
      assert JsonContext.can_apply_repair?(context, :comma_fix) == false
    end

    test "allows string delimiter repair when in string" do
      context = %JsonContext{
        current: :object_value,
        stack: [:root],
        position: 5,
        in_string: true,
        string_delimiter: "\""
      }

      assert JsonContext.can_apply_repair?(context, :string_delimiter) == true
    end
  end
end
