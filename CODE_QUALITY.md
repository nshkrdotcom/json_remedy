Below is a detailed **Elixir Code Style Guide** that incorporates the features you asked about (`@type t` and `@enforce_keys`) and other related Elixir constructs, such as structs, type specifications, module attributes, and documentation. This guide is designed to promote consistency, readability, and maintainability in Elixir codebases, with examples grounded in the context of the `Quantum.NodeSelectorBroadcaster.StartOpts` module you provided. It also includes best practices for similar features and conventions commonly used in Elixir projects.

# Elixir Code Style Guide

This style guide outlines conventions and best practices for writing clean, consistent, and maintainable Elixir code. It emphasizes Elixir's idiomatic features, including structs, type specifications, module attributes, and documentation, while incorporating specific guidance for features like `@type t` and `@enforce_keys`. The goal is to ensure code is readable, well-documented, and robust for both development and production use.

## Table of Contents

1.  [General Principles](https://www.google.com/search?q=%231-general-principles)
2.  [Module Structure and Attributes](https://www.google.com/search?q=%232-module-structure-and-attributes)
3.  [Structs and `@enforce_keys`](https://www.google.com/search?q=%233-structs-and-enforce_keys)
4.  [Type Specifications (`@type`, `@type t`, `@spec`)](https://www.google.com/search?q=%234-type-specifications-type-type-t-spec)
5.  [Documentation (`@moduledoc`, `@doc`)](https://www.google.com/search?q=%235-documentation-moduledoc-doc)
6.  [Naming Conventions](https://www.google.com/search?q=%236-naming-conventions)
7.  [Code Formatting](https://www.google.com/search?q=%237-code-formatting)
8.  [Best Practices for Related Features](https://www.google.com/search?q=%238-best-practices-for-related-features)
9.  [Example Implementation](https://www.google.com/search?q=%239-example-implementation)
10. [Tools for Code Quality](https://www.google.com/search?q=%2310-tools-for-code-quality)

-----

## 1\. General Principles

  * **Clarity over Cleverness**: Write code that's easy to understand and maintain, even if it means being more verbose.
  * **Consistency**: Follow this guide within a project to ensure uniformity across the codebase.
  * **Leverage Elixir Features**: Use Elixir’s built-in tools (e.g., structs, type specs, module attributes) to improve code reliability and documentation.
  * **Use Tooling**: Rely on tools like `mix format`, Dialyzer, and Credo to enforce style and catch errors.

-----

## 2\. Module Structure and Attributes

Modules are the primary organizational unit in Elixir. Structure them clearly and use module attributes effectively.

### Module Naming

  * Use **CamelCase** for module names, reflecting their purpose (e.g., `Quantum.NodeSelectorBroadcaster.StartOpts`).
  * Nest modules logically to reflect their hierarchy (e.g., `Quantum.NodeSelectorBroadcaster` for a broadcaster within the `Quantum` library).

### Module Attributes

  * Use `@moduledoc` to document the module’s purpose at the top of the file.
  * Use `@doc` for public functions and structs.
  * Reserve module attributes like `@enforce_keys`, `@type`, and `@spec` for their specific purposes (see below).
  * Avoid using module attributes for runtime data unless necessary; prefer constants or configuration.

**Example**:

```elixir
defmodule Quantum.NodeSelectorBroadcaster.StartOpts do
  @moduledoc """
  Configuration struct for starting a Quantum NodeSelectorBroadcaster.
  Defines required options for initializing the broadcaster process.
  """
  # Module attributes for struct and type specs
  @enforce_keys [:name, :execution_broadcaster_reference, :task_supervisor_reference]
  defstruct @enforce_keys
  @type t :: %__MODULE___{
          name: GenServer.server(),
          execution_broadcaster_reference: GenServer.server(),
          task_supervisor_reference: GenServer.server()
        }
end
```

-----

## 3\. Structs and `@enforce_keys`

Structs in Elixir are a powerful way to define structured data with enforced constraints. The `@enforce_keys` attribute ensures required fields are provided during struct creation.

### Guidelines

  * **Use Structs for Well-Defined Data**:
      * Define structs for data with a fixed structure, such as configuration options or domain models (e.g., `StartOpts` for broadcaster configuration).
      * Use `defstruct` to define the fields, leveraging `@enforce_keys` for required fields.
  * **Enforce Required Fields with `@enforce_keys`**:
      * List fields in `@enforce_keys` that must always have non-nil values.
      * Ensure `@enforce_keys` matches the fields in `defstruct` unless optional fields are explicitly allowed.
      * **Example**: `@enforce_keys [:name, :reference]` ensures these fields are provided and non-nil.
  * **Avoid Overusing Structs**:
      * Use structs for data with clear semantics; use maps for flexible or dynamic data.
  * **Default Values**:
      * Avoid defaults in `defstruct` unless truly optional, as `@enforce_keys` requires non-nil values for listed fields.
      * If defaults are needed, define them explicitly in `defstruct` for non-enforced fields (e.g., `defstruct @enforce_keys ++ [timeout: 5000]`).

**Example**

```elixir
defmodule Quantum.NodeSelectorBroadcaster.StartOpts do
  @enforce_keys [:name, :execution_broadcaster_reference, :task_supervisor_reference]
  defstruct @enforce_keys

  # Valid creation
  def example do
    %__MODULE___{
      name: :broadcaster,
      execution_broadcaster_reference: {:global, :exec_broadcaster},
      task_supervisor_reference: {:global, :task_sup}
    }
  end
end
```

**Error Cases**:

```elixir
# Missing key
%Quantum.NodeSelectorBroadcaster.StartOpts{name: :broadcaster}
# => ** (KeyError) key :execution_broadcaster_reference not found

# Nil value for enforced key
%Quantum.NodeSelectorBroadcaster.StartOpts{
  name: :broadcaster,
  execution_broadcaster_reference: nil,
  task_supervisor_reference: {:global, :task_sup}
}
# => ** (KeyError) key :execution_broadcaster_reference cannot be nil
```

-----

## 4\. Type Specifications (`@type`, `@type t`, `@spec`)

Type specifications improve code reliability, enable static analysis with Dialyzer, and enhance documentation.

### Guidelines

  * **Define a `@type t` for Structs**:
      * Every module defining a struct should include a `@type t` specifying the struct’s structure.
      * Use `%__MODULE__{...}` to define the struct type, listing all fields and their types.
      * **Example**: `@type t :: %__MODULE___{name: GenServer.server(), ...}`.
  * **Use Descriptive Types**:
      * Use built-in types (e.g., `atom()`, `pid()`, `GenServer.server()`) or custom types for fields.
      * Define custom types with `@type` for complex or reusable types.
  * **Function Specifications with `@spec`**:
      * Add `@spec` for all public functions to document their input and output types.
      * Reference `@type t` in function specs for structs.
  * **Private Types**:
      * Use `@typep` for types only used within the module.
  * **Placement**:
      * Place type definitions near the top of the module, after `@moduledoc` and before function definitions.
      * Group related types together for clarity.

**Example**

```elixir
defmodule Quantum.NodeSelectorBroadcaster do
  @moduledoc """
  A GenServer for broadcasting node selection events in the Quantum scheduler.
  """
  @type t :: %__MODULE__.StartOpts{
          name: GenServer.server(),
          execution_broadcaster_reference: GenServer.server(),
          task_supervisor_reference: GenServer.server()
        }
  @typep internal_state :: %{
           broadcaster: GenServer.server(),
           tasks: map()
         }

  @spec start_link(t()) :: GenServer.on_start()
  def start_link(%__MODULE__.StartOpts{} = opts) do
    GenServer.start_link(__MODULE__, opts, name: opts.name)
  end
end
```

-----

## 5\. Documentation (`@moduledoc`, `@doc`)

Good documentation is critical for maintainability and collaboration.

### Guidelines

  * **Module Documentation (`@moduledoc`)**:
      * Every module should have a `@moduledoc` describing its purpose and usage.
      * Mark internal modules with `@moduledoc false` to suppress documentation generation (as in the original example).
      * Use clear, concise language and Markdown formatting for readability.
  * **Function and Struct Documentation (`@doc`)**:
      * Document all public functions and structs with `@doc`.
      * Include examples, expected inputs, and return values.
      * Use `@doc false` for private functions if documentation is needed internally.
  * **Reference Types**:
      * Mention relevant types (e.g., `@type t`) in `@moduledoc` or `@doc` for clarity.
  * **Examples**:
      * Include code examples in `@doc` using Markdown code blocks (`elixir`).
      * Show both success and error cases where applicable.

**Example**

```elixir
defmodule Quantum.NodeSelectorBroadcaster.StartOpts do
  @moduledoc """
  A struct for configuring a `Quantum.NodeSelectorBroadcaster`.
  Defines required fields for initializing the broadcaster process.
  See `@type t` for the struct's type specification.
  """
  @enforce_keys [:name, :execution_broadcaster_reference, :task_supervisor_reference]
  defstruct @enforce_keys

  @type t :: %__MODULE___{
          name: GenServer.server(),
          execution_broadcaster_reference: GenServer.server(),
          task_supervisor_reference: GenServer.server()
        }

  @doc """
  Creates a new `StartOpts` struct.

  ## Examples

      iex> %Quantum.NodeSelectorBroadcaster.StartOpts{
      ...>   name: :broadcaster,
      ...>   execution_broadcaster_reference: {:global, :exec_broadcaster},
      ...>   task_supervisor_reference: {:global, :task_sup}
      ...> }
      %Quantum.NodeSelectorBroadcaster.StartOpts{...}
  """
  def new(name, exec_ref, task_ref) do
    %__MODULE__{
      name: name,
      execution_broadcaster_reference: exec_ref,
      task_supervisor_reference: task_ref
    }
  end
end
```

-----

## 6\. Naming Conventions

  * **Modules**: Use **CamelCase** (e.g., `NodeSelectorBroadcaster`).
  * **Functions and Variables**: Use **snake\_case** (e.g., `start_link`, `task_supervisor_reference`).
  * **Struct Fields**: Use **snake\_case** for field names, matching function and variable conventions.
  * **Type Names**: Use **snake\_case** for custom types (e.g., `@type my_type :: term()`).
  * **Atoms**: Use **snake\_case** for atoms (e.g., `:execution_broadcaster_reference`).
  * **Descriptive Names**: Choose names that clearly describe the purpose (e.g., `task_supervisor_reference` indicates a reference to a task supervisor).

-----

## 7\. Code Formatting

  * **Use `mix format`**:
      * Run `mix format` to enforce consistent code formatting across the project.
      * Configure `.formatter.exs` to include all source files (e.g., `lib/`, `test/`).
  * **Line Length**:
      * Aim for lines under 98 characters, as recommended by Elixir’s formatter.
      * Break long lines using Elixir’s pipeline operator (`|>`) or clear indentation.
  * **Indentation**:
      * Use 2 spaces for indentation (enforced by `mix format`).
  * **Struct Definitions**:
      * Align struct fields vertically for readability:
    <!-- end list -->
    ```elixir
    @type t :: %__MODULE___{
            name: GenServer.server(),
            execution_broadcaster_reference: GenServer.server(),
            task_supervisor_reference: GenServer.server()
          }
    ```

-----

## 8\. Best Practices for Related Features

### Module Attributes

  * Use module attributes for compile-time configuration (e.g., `@enforce_keys`, `@type`).
  * Avoid storing runtime state in module attributes, as they are evaluated at compile time.

### Structs

  * Use structs for domain-specific data with fixed fields (e.g., configuration structs like `StartOpts`).
  * Combine with `@enforce_keys` for required fields and `@type t` for type safety.

### Behaviours

  * Define behaviours for modules that share a common interface (e.g., `GenServer` for `Quantum.NodeSelectorBroadcaster`).
    **Example**:

<!-- end list -->

```elixir
defmodule Quantum.NodeSelectorBroadcaster do
  @behaviour GenServer
  # ...
end
```

### Pattern Matching

  * Use pattern matching in function clauses to validate struct inputs:

<!-- end list -->

```elixir
def start_link(%__MODULE__.StartOpts{} = opts), do: GenServer.start_link(__MODULE__, opts)
```

### Error Handling

  * Use `with` or pattern matching for robust error handling when working with structs.
    **Example**:

<!-- end list -->

```elixir
def validate_opts(%__MODULE__.StartOpts{} = opts) do
  with :ok <- validate_name(opts.name),
       :ok <- validate_reference(opts.execution_broadcaster_reference),
       :ok <- validate_reference(opts.task_supervisor_reference) do
    {:ok, opts}
  else
    error -> {:error, error}
  end
end
```

-----

## 9\. Example Implementation

Here’s a complete example incorporating the above guidelines, expanding on the `Quantum.NodeSelectorBroadcaster.StartOpts` module:

```elixir
defmodule Quantum.NodeSelectorBroadcaster.StartOpts do
  @moduledoc """
  A struct for configuring a `Quantum.NodeSelectorBroadcaster` process.

  This struct defines the required configuration for initializing a broadcaster
  process in the Quantum job scheduler. All fields are enforced to ensure proper
  configuration.

  ## Fields
  - `name`: The name of the broadcaster process (`GenServer.server()`).
  - `execution_broadcaster_reference`: Reference to the execution broadcaster.
  - `task_supervisor_reference`: Reference to the task supervisor.

  See `@type t` for the type specification.
  """
  @enforce_keys [:name, :execution_broadcaster_reference, :task_supervisor_reference]
  defstruct @enforce_keys

  @type t :: %__MODULE___{
          name: GenServer.server(),
          execution_broadcaster_reference: GenServer.server(),
          task_supervisor_reference: GenServer.server()
        }

  @doc """
  Creates a new `StartOpts` struct with the given parameters.

  ## Parameters
  - `name`: The name of the broadcaster process.
  - `exec_ref`: The execution broadcaster reference.
  - `task_ref`: The task supervisor reference.

  ## Returns
  - A `%StartOpts{}` struct if all parameters are valid.
  - Raises a `KeyError` if any enforced key is missing or `nil`.

  ## Examples

      iex> Quantum.NodeSelectorBroadcaster.StartOpts.new(
      ...>   :broadcaster,
      ...>   {:global, :exec_broadcaster},
      ...>   {:global, :task_sup}
      ...> )
      %Quantum.NodeSelectorBroadcaster.StartOpts{
        name: :broadcaster,
        execution_broadcaster_reference: {:global, :exec_broadcaster},
        task_supervisor_reference: {:global, :task_sup}
      }
  """
  @spec new(GenServer.server(), GenServer.server(), GenServer.server()) :: t()
  def new(name, exec_ref, task_ref) do
    %__MODULE__{
      name: name,
      execution_broadcaster_reference: exec_ref,
      task_supervisor_reference: task_ref
    }
  end

  @doc """
  Validates a `StartOpts` struct.

  ## Parameters
  - `opts`: The `%StartOpts{}` struct to validate.

  ## Returns
  - `{:ok, opts}` if valid.
  - `{:error, reason}` if invalid.

  ## Examples

      iex> opts = Quantum.NodeSelectorBroadcaster.StartOpts.new(:broadcaster, {:global, :exec}, {:global, :task})
      iex> Quantum.NodeSelectorBroadcaster.StartOpts.validate(opts)
      {:ok, opts}
  """
  @spec validate(t()) :: {:ok, t()} | {:error, term()}
  def validate(%__MODULE__{} = opts) do
    {:ok, opts}
  end
end
```

-----

## 10\. Tools for Code Quality

  * **`mix format`**: Enforce consistent code formatting.
      * **Run**: `mix format`
      * **Configure**: Update `.formatter.exs` for project-specific rules.
  * **Dialyzer**: Static analysis for type checking.
      * **Run**: `mix dialyzer`
      * Ensure all public functions and structs have `@spec` and `@type`.
  * **Credo**: Linting for code style and best practices.
      * **Run**: `mix credo`
      * **Configure**: Customize `.credo.exs` for project-specific checks.
  * **ExDoc**: Generate documentation from `@moduledoc` and `@doc`.
      * **Run**: `mix docs`
      * Ensure all public APIs are documented.

-----

## Conclusion

This style guide provides a comprehensive framework for writing Elixir code that is consistent, readable, and robust. By leveraging features like `@type t`, `@enforce_keys`, `@spec`, and `@moduledoc`, developers can create well-documented, type-safe, and maintainable code. The example implementation demonstrates how these features work together in a real-world context, such as configuring a `Quantum.NodeSelectorBroadcaster` process. Adhering to these guidelines, combined with Elixir’s tooling, ensures high-quality codebases that are easy to understand and extend.

Do you have any specific additions you'd like to make, or are there other Elixir features you'd like to explore in more detail?
