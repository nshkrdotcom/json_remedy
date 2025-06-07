defmodule JsonRemedy do
  @moduledoc """
  A blazingly fast, Elixir-native JSON repair library.

  JsonRemedy uses advanced binary pattern matching and functional composition
  to intelligently repair malformed JSON strings while achieving superior performance.

  ## Examples

      iex> JsonRemedy.repair(~s|{name: "Alice", age: 30, active: True}|)
      {:ok, %{"name" => "Alice", "age" => 30, "active" => true}}

      iex> JsonRemedy.repair_to_string(~s|[1, 2, 3,]|)
      {:ok, "[1,2,3]"}

      iex> JsonRemedy.repair(~s|{incomplete: "data"|, logging: true)
      {:ok, %{"incomplete" => "data"}, ["added missing closing brace"]}
  """

  alias JsonRemedy.BinaryParser
  alias JsonRemedy.Combinators
  alias JsonRemedy.Pipeline

  @type repair_result :: {:ok, term()} | {:error, String.t()}
  @type repair_result_with_logs :: {:ok, term(), [String.t()]} | {:error, String.t()}
  @type strategy :: :binary_patterns | :combinators | :streaming
  @type option :: {:logging, boolean()} | {:strategy, strategy()} | {:strict, boolean()}

  @doc """
  Repairs malformed JSON and returns the parsed Elixir term.

  ## Options

  - `logging: true` - Returns repair actions taken as third element in tuple
  - `strategy: :binary_patterns` - Use binary pattern matching (default, fastest)
  - `strategy: :combinators` - Use parser combinators (most elegant)
  - `strategy: :streaming` - Use stream processing (for large files)
  - `strict: false` - Allow non-standard JSON extensions (default true)

  ## Examples

      iex> JsonRemedy.repair(~s|{"name": "John", "age": 30}|)
      {:ok, %{"name" => "John", "age" => 30}}

      iex> JsonRemedy.repair(~s|{name: "John", age: 30, active: True}|)
      {:ok, %{"name" => "John", "age" => 30, "active" => true}}

      iex> JsonRemedy.repair(~s|[1, 2, 3,]|, logging: true)
      {:ok, [1, 2, 3], ["removed trailing comma"]}
  """
  @spec repair(binary(), [option()]) :: repair_result() | repair_result_with_logs()
  def repair(json_string, opts \\ []) when is_binary(json_string) do
    strategy = Keyword.get(opts, :strategy, :binary_patterns)
    logging = Keyword.get(opts, :logging, false)

    # First try standard JSON parsing
    case Jason.decode(json_string) do
      {:ok, result} ->
        if logging, do: {:ok, result, []}, else: {:ok, result}
      {:error, _} ->
        # Standard parsing failed, use repair strategy
        apply_repair_strategy(strategy, json_string, opts)
    end
  end

  @doc """
  Repairs malformed JSON and returns the fixed JSON string.

  ## Examples

      iex> JsonRemedy.repair_to_string(~s|{name: "Alice"}|)
      {:ok, ~s|{"name":"Alice"}|}

      iex> JsonRemedy.repair_to_string(~s|[1, 2, 3,]|)
      {:ok, "[1,2,3]"}
  """
  @spec repair_to_string(binary(), [option()]) :: {:ok, binary()} | {:error, String.t()}
  def repair_to_string(json_string, opts \\ []) when is_binary(json_string) do
    case repair(json_string, opts) do
      {:ok, term} ->
        {:ok, Jason.encode!(term)}
      {:ok, term, _repairs} ->
        {:ok, Jason.encode!(term)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Repairs JSON content directly from a file.

  ## Examples

      iex> JsonRemedy.from_file("config.json")
      {:ok, %{"setting" => "value"}}

      iex> JsonRemedy.from_file("malformed.json", logging: true)
      {:ok, %{"data" => "value"}, ["quoted unquoted keys", "added missing comma"]}
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

  Useful for processing large files or real-time data streams.

  ## Examples

      "large_file.json"
      |> File.stream!()
      |> JsonRemedy.repair_stream()
      |> Stream.each(&IO.inspect/1)
      |> Stream.run()
  """
  @spec repair_stream(Enumerable.t()) :: Enumerable.t()
  def repair_stream(stream) do
    stream
    |> Stream.map(&repair/1)
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

  # Private implementation functions

  defp apply_repair_strategy(:binary_patterns, json_string, opts) do
    BinaryParser.repair(json_string, opts)
  end

  defp apply_repair_strategy(:combinators, json_string, opts) do
    Combinators.repair(json_string, opts)
  end

  defp apply_repair_strategy(:streaming, json_string, opts) do
    Pipeline.repair(json_string, opts)
  end

  defp apply_repair_strategy(unknown, _json_string, _opts) do
    {:error, "Unknown strategy: #{inspect(unknown)}"}
  end
end
