defmodule JsonRemedy do
  @moduledoc """
  A blazingly fast, Elixir-native JSON repair library.

  JsonRemedy uses a layered architecture with binary pattern matching to intelligently
  repair malformed JSON strings while achieving superior performance.

  This module provides the main API for JSON repair functionality. It supports
  multiple repair strategies and can handle various types of malformed JSON through
  a four-layer processing pipeline:

  - **Layer 1**: Content Cleaning (removes code fences, comments, extra text)
  - **Layer 2**: Structural Repair (fixes missing braces, brackets, etc.)
  - **Layer 3**: Syntax Normalization (quotes, booleans, commas, colons)
  - **Layer 4**: Validation (validates and parses the final JSON)

  ## Examples

      iex> JsonRemedy.repair(~s|{name: "Alice", age: 30, active: True}|)
      {:ok, %{"name" => "Alice", "age" => 30, "active" => true}}

      iex> JsonRemedy.repair_to_string(~s|[1, 2, 3,]|)
      {:ok, "[1,2,3]"}

      iex> JsonRemedy.repair(~s|{incomplete: "data"|, logging: true)
      {:ok, %{"incomplete" => "data"}, [%{layer: :layer2, action: "added missing closing brace"}]}
  """

  alias JsonRemedy.Layer1.ContentCleaning
  alias JsonRemedy.Layer2.StructuralRepair
  alias JsonRemedy.Layer3.SyntaxNormalization
  alias JsonRemedy.Layer4.Validation

  # Type definitions
  @type json_value ::
          nil | boolean() | number() | String.t() | [json_value()] | %{String.t() => json_value()}
  @type repair_action :: %{layer: atom(), action: String.t()}
  @type repair_result :: {:ok, json_value()} | {:error, String.t()}
  @type repair_result_with_logs :: {:ok, json_value(), [repair_action()]} | {:error, String.t()}
  @type option ::
          {:logging, boolean()}
          | {:jason_options, keyword()}
          | {:fast_path_optimization, boolean()}

  @doc """
  Repairs malformed JSON and returns the parsed Elixir term.

  Processes the input through all four layers of the JsonRemedy pipeline to fix
  common JSON formatting issues and return a parsed Elixir data structure.

  ## Options

  - `logging: true` - Returns repair actions taken as third element in tuple
  - `jason_options: []` - Options to pass to Jason for final parsing
  - `fast_path_optimization: true` - Enable fast path for already valid JSON (default)

  ## Examples

      iex> JsonRemedy.repair(~s|{"name": "John", "age": 30}|)
      {:ok, %{"name" => "John", "age" => 30}}

      iex> JsonRemedy.repair(~s|{name: "John", age: 30, active: True}|)
      {:ok, %{"name" => "John", "age" => 30, "active" => true}}

      iex> JsonRemedy.repair(~s|[1, 2, 3,]|, logging: true)
      {:ok, [1, 2, 3], [%{layer: :layer3, action: "removed trailing comma"}]}

      iex> JsonRemedy.repair(~s|```json\n{"valid": true}\n```|)
      {:ok, %{"valid" => true}}
  """
  @spec repair(binary(), [option()]) :: repair_result() | repair_result_with_logs()
  def repair(json_string, opts \\ []) when is_binary(json_string) do
    logging = Keyword.get(opts, :logging, false)
    jason_options = Keyword.get(opts, :jason_options, [])
    fast_path = Keyword.get(opts, :fast_path_optimization, true)

    # Initialize context
    context = %{
      repairs: [],
      options: [
        jason_options: jason_options,
        fast_path_optimization: fast_path
      ],
      metadata: %{}
    }

    # Try fast path first if enabled
    if fast_path do
      case Jason.decode(json_string, jason_options) do
        {:ok, result} ->
          if logging, do: {:ok, result, []}, else: {:ok, result}

        {:error, _} ->
          # Fast path failed, use full pipeline
          process_through_pipeline(json_string, context, logging)
      end
    else
      # Skip fast path, use full pipeline
      process_through_pipeline(json_string, context, logging)
    end
  end

  @doc """
  Repairs malformed JSON and returns the fixed JSON string.

  Like `repair/2`, but returns the repaired JSON as a string rather than parsing it.

  ## Examples

      iex> JsonRemedy.repair_to_string(~s|{name: "Alice"}|)
      {:ok, ~s|{"name":"Alice"}|}

      iex> JsonRemedy.repair_to_string(~s|[1, 2, 3,]|)
      {:ok, "[1,2,3]"}

      iex> JsonRemedy.repair_to_string(~s|```json\n{"test": true}\n```|)
      {:ok, ~s|{"test":true}|}
  """
  @spec repair_to_string(binary(), [option()]) :: {:ok, binary()} | {:error, String.t()}
  def repair_to_string(json_string, opts \\ []) when is_binary(json_string) do
    case repair(json_string, opts) do
      {:ok, term} ->
        jason_options = Keyword.get(opts, :jason_options, [])
        {:ok, Jason.encode!(term, jason_options)}

      {:ok, term, _repairs} ->
        jason_options = Keyword.get(opts, :jason_options, [])
        {:ok, Jason.encode!(term, jason_options)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Repairs JSON content directly from a file.

  Reads the file and processes it through the JsonRemedy pipeline.

  ## Examples

      iex> JsonRemedy.from_file("config.json")
      {:ok, %{"setting" => "value"}}

      iex> JsonRemedy.from_file("malformed.json", logging: true)
      {:ok, %{"data" => "value"}, [%{layer: :layer1, action: "removed code fences"}]}
  """
  @spec from_file(Path.t(), [option()]) :: repair_result() | repair_result_with_logs()
  def from_file(path, opts \\ []) do
    case File.read(path) do
      {:ok, content} -> repair(content, opts)
      {:error, reason} -> {:error, "Could not read file: #{inspect(reason)}"}
    end
  end

  @doc """
  Creates a stream that repairs JSON objects from an input stream.

  Useful for processing large files or real-time data streams. Each item in the
  stream is processed independently through the JsonRemedy pipeline.

  ## Examples

      "large_file.jsonl"
      |> File.stream!()
      |> JsonRemedy.repair_stream()
      |> Stream.each(&IO.inspect/1)
      |> Stream.run()
  """
  @spec repair_stream(Enumerable.t(), [option()]) :: Enumerable.t()
  def repair_stream(stream, opts \\ []) do
    stream
    |> Stream.map(&repair(&1, opts))
    |> Stream.filter(fn
      {:ok, _} -> true
      {:ok, _, _} -> true
      {:error, _} -> false
    end)
    |> Stream.map(fn
      {:ok, result} -> result
      {:ok, result, _} -> result
    end)
  end

  @doc """
  Checks if a string appears to be malformed JSON that JsonRemedy can fix.

  Returns `true` if the input has issues that JsonRemedy layers can address.

  ## Examples

      iex> JsonRemedy.can_repair?(~s|{"valid": true}|)
      false

      iex> JsonRemedy.can_repair?(~s|{name: "Alice"}|)
      true

      iex> JsonRemedy.can_repair?(~s|```json\n{"test": true}\n```|)
      true
  """
  @spec can_repair?(binary()) :: boolean()
  def can_repair?(json_string) when is_binary(json_string) do
    ContentCleaning.supports?(json_string) or
      StructuralRepair.supports?(json_string) or
      SyntaxNormalization.supports?(json_string)
  end

  @doc """
  Returns information about what repairs would be applied to the input.

  Processes through the pipeline but returns detailed information about what
  each layer would do without actually applying the repairs.

  ## Examples

      iex> JsonRemedy.analyze(~s|{name: 'Alice', active: True}|)
      {:ok, [
        %{layer: :layer3, action: "normalize single quotes to double quotes"},
        %{layer: :layer3, action: "normalize Python-style boolean True to true"}
      ]}
  """
  @spec analyze(binary()) :: {:ok, [repair_action()]} | {:error, String.t()}
  def analyze(json_string) when is_binary(json_string) do
    context = %{repairs: [], options: [], metadata: %{}}

    # Process through pipeline but focus on collecting repairs
    case process_through_pipeline(json_string, context, true) do
      {:ok, _, repairs} -> {:ok, repairs}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private implementation functions

  defp process_through_pipeline(input, context, logging) do
    # Layer 1: Content Cleaning
    with {:ok, output1, context1} <- ContentCleaning.process(input, context),
         # Layer 2: Structural Repair
         {:ok, output2, context2} <- StructuralRepair.process(output1, context1),
         # Layer 3: Syntax Normalization
         {:ok, output3, context3} <- SyntaxNormalization.process(output2, context2),
         # Layer 4: Validation
         {:ok, parsed, final_context} <- Validation.process(output3, context3) do
      if logging do
        {:ok, parsed, final_context.repairs}
      else
        {:ok, parsed}
      end
    else
      {:continue, _, _} ->
        {:error, "Could not repair JSON - all layers processed but validation failed"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
