defmodule JsonRemedy do
  @moduledoc """
  A blazingly fast, Elixir-native JSON repair library.

  JsonRemedy uses a layered architecture with binary pattern matching to intelligently
  repair malformed JSON strings while achieving superior performance.

  This module provides the main API for JSON repair functionality. It supports
  multiple repair strategies and can handle various types of malformed JSON through
  a four-layer processing pipeline with intelligent preprocessing:

  - **Preprocessing**: Multiple JSON detection (Pattern 1)
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
      {:ok, %{"incomplete" => "data"}, [
        %{layer: :structural_repair, action: "added missing closing brace", position: 18, original: nil, replacement: "}"},
        %{layer: :syntax_normalization, action: "quoted unquoted key", position: 1, original: nil, replacement: nil}
      ]}
  """

  alias JsonRemedy.Layer1.ContentCleaning
  alias JsonRemedy.Layer2.StructuralRepair
  alias JsonRemedy.Layer3.SyntaxNormalization
  alias JsonRemedy.Layer4.Validation
  alias JsonRemedy.Utils.MultipleJsonDetector

  # Type definitions
  @type json_value ::
          nil | boolean() | number() | String.t() | [json_value()] | %{String.t() => json_value()}
  @type repair_action :: %{layer: atom(), action: String.t()}
  @type repair_result :: {:ok, json_value()} | {:error, String.t()}
  @type repair_result_with_logs :: {:ok, json_value(), [repair_action()]} | {:error, String.t()}
  @type option ::
          {:logging, boolean()}
          | {:debug, boolean()}
          | {:jason_options, keyword()}
          | {:fast_path_optimization, boolean()}

  @doc """
  Repairs malformed JSON and returns the parsed Elixir term.

  Processes the input through all four layers of the JsonRemedy pipeline to fix
  common JSON formatting issues and return a parsed Elixir data structure.

  ## Options

  - `logging: true` - Returns repair actions taken as third element in tuple
  - `debug: true` - Returns detailed step-by-step debugging information
  - `jason_options: []` - Options to pass to Jason for final parsing
  - `fast_path_optimization: true` - Enable fast path for already valid JSON (default)

  ## Examples

      iex> JsonRemedy.repair(~s|{"name": "John", "age": 30}|)
      {:ok, %{"name" => "John", "age" => 30}}

      iex> JsonRemedy.repair(~s|{name: "John", age: 30, active: True}|)
      {:ok, %{"name" => "John", "age" => 30, "active" => true}}

      iex> JsonRemedy.repair(~s|[1, 2, 3,]|, logging: true)
      {:ok, [1, 2, 3], [%{layer: :syntax_normalization, action: "removed trailing comma", position: 8, original: nil, replacement: nil}]}

      iex> JsonRemedy.repair(~s/```json\\n{"valid": true}\\n```/)
      {:ok, %{"valid" => true}}
  """
  @spec repair(binary(), [option()]) :: repair_result() | repair_result_with_logs()
  def repair(json_string, opts \\ []) when is_binary(json_string) do
    logging = Keyword.get(opts, :logging, false)
    debug = Keyword.get(opts, :debug, false)
    jason_options = Keyword.get(opts, :jason_options, [])
    fast_path = Keyword.get(opts, :fast_path_optimization, true)

    # If debug is requested, use the debug function
    if debug do
      repair_with_debug(json_string, opts)
    else
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
  end

  @doc """
  Repairs malformed JSON and returns the fixed JSON string.

  Like `repair/2`, but returns the repaired JSON as a string rather than parsing it.

  ## Examples

      iex> JsonRemedy.repair_to_string(~s|{name: "Alice"}|)
      {:ok, ~s|{"name":"Alice"}|}

      iex> JsonRemedy.repair_to_string(~s|[1, 2, 3,]|)
      {:ok, "[1,2,3]"}

      iex> JsonRemedy.repair_to_string(~s/```json\\n{"test": true}\\n```/)
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

      iex> {:ok, result} = JsonRemedy.from_file("test/data/invalid.json")
      iex> is_list(result)
      true

      iex> JsonRemedy.from_file("nonexistent.json", logging: true)
      {:error, "Could not read file: :enoent"}
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

      iex> JsonRemedy.can_repair?(~s/```json\\n{"test": true}\\n```/)
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
        %{layer: :syntax_normalization, action: "normalized boolean", position: 24, original: nil, replacement: nil},
        %{layer: :syntax_normalization, action: "quoted unquoted key", position: 16, original: nil, replacement: nil},
        %{layer: :syntax_normalization, action: "normalized quotes", position: 7, original: nil, replacement: nil},
        %{layer: :syntax_normalization, action: "quoted unquoted key", position: 1, original: nil, replacement: nil}
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

  @doc """
  Repairs malformed JSON with detailed debugging information.

  Returns comprehensive information about each step of the repair process,
  including what each layer attempted to do and why it succeeded or failed.

  ## Examples

      iex> {:ok, result, debug} = JsonRemedy.repair_with_debug(~s|{name: 'Alice', active: True}|)
      iex> result
      %{"name" => "Alice", "active" => true}
      iex> debug.total_repairs
      4
      iex> length(debug.steps)
      4
  """
  @spec repair_with_debug(binary(), [option()]) ::
          {:ok, json_value(),
           %{
             steps: [map()],
             total_repairs: non_neg_integer(),
             processing_time_us: non_neg_integer()
           }}
          | {:error, String.t(),
             %{
               steps: [map()],
               total_repairs: non_neg_integer(),
               processing_time_us: non_neg_integer()
             }}
  def repair_with_debug(json_string, opts \\ []) when is_binary(json_string) do
    start_time = System.monotonic_time(:microsecond)
    jason_options = Keyword.get(opts, :jason_options, [])
    fast_path = Keyword.get(opts, :fast_path_optimization, true)

    # Initialize context with debug tracking
    context = %{
      repairs: [],
      options: [
        jason_options: jason_options,
        fast_path_optimization: fast_path,
        debug: true
      ],
      metadata: %{},
      debug_steps: []
    }

    # Try fast path first if enabled
    result =
      if fast_path do
        case Jason.decode(json_string, jason_options) do
          {:ok, result} ->
            end_time = System.monotonic_time(:microsecond)

            debug_info = %{
              steps: [
                %{layer: :fast_path, status: :validated, input_size: byte_size(json_string)}
              ],
              total_repairs: 0,
              processing_time_us: end_time - start_time
            }

            {:ok, result, debug_info}

          {:error, _} ->
            # Fast path failed, use full pipeline with debug
            process_through_pipeline_with_debug(json_string, context, start_time)
        end
      else
        # Skip fast path, use full pipeline with debug
        process_through_pipeline_with_debug(json_string, context, start_time)
      end

    result
  end

  # Private implementation functions

  defp process_through_pipeline(input, context, logging) do
    # Pre-processing: Detect multiple JSON values (Pattern 1)
    # Must run BEFORE layers because:
    # - Layer 1 may remove additional JSON as "wrapper text"
    # - Layer 3 adds commas between ]{ which breaks the pattern
    enable_multiple_json =
      Application.get_env(:json_remedy, :enable_multiple_json_aggregation, true)

    if enable_multiple_json do
      case MultipleJsonDetector.parse_multiple(input) do
        {:ok, result} when is_list(result) and length(result) > 1 ->
          # Multiple values detected
          if logging do
            {:ok, result, context.repairs}
          else
            {:ok, result}
          end

        _ ->
          # Single value, continue normal pipeline
          process_normal_pipeline(input, context, logging)
      end
    else
      process_normal_pipeline(input, context, logging)
    end
  end

  defp process_normal_pipeline(input, context, logging) do
    # Pre-processing: Object boundary merging (before Layer 1 to prevent wrapper text removal)
    {input_after_merge, _merge_repairs} =
      if Application.get_env(:json_remedy, :enable_object_merging, true) do
        JsonRemedy.Layer3.ObjectMerger.merge_object_boundaries(input)
      else
        {input, []}
      end

    # Pre-processing: Hardcoded patterns (CRITICAL: must run before Layer 2!)
    # This prevents Layer 2 from misinterpreting doubled quotes as unclosed structures
    input_after_hardcoded =
      if Application.get_env(:json_remedy, :enable_early_hardcoded_patterns, true) do
        input_after_merge
        |> JsonRemedy.Layer3.HardcodedPatterns.normalize_smart_quotes()
        |> JsonRemedy.Layer3.HardcodedPatterns.fix_doubled_quotes()
      else
        input_after_merge
      end

    # Layer 1: Content Cleaning
    with {:ok, output1, context1} <- ContentCleaning.process(input_after_hardcoded, context),
         # Layer 2: Structural Repair
         {:ok, output2, context2} <- StructuralRepair.process(output1, context1),
         # Layer 3: Syntax Normalization
         {:ok, output3, context3} <- SyntaxNormalization.process(output2, context2),
         # Layer 4: Validation
         {:ok, parsed, final_context} <- Validation.process(output3, context3) do
      # Pipeline succeeded
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

  @spec process_through_pipeline_with_debug(
          binary(),
          %{debug_steps: list(), metadata: map(), options: list(), repairs: list()},
          integer()
        ) ::
          {:ok, json_value(),
           %{processing_time_us: integer(), steps: [map()], total_repairs: non_neg_integer()}}
          | {:error, binary(),
             %{
               error_at_layer: atom(),
               processing_time_us: integer(),
               steps: [map()],
               total_repairs: non_neg_integer()
             }}
  defp process_through_pipeline_with_debug(input, context, start_time) do
    debug_steps = []

    # Layer 1: Content Cleaning
    case process_layer_with_debug(ContentCleaning, input, context, debug_steps, :layer1) do
      {{:error, reason}, context1, debug_steps} ->
        end_time = System.monotonic_time(:microsecond)

        debug_info = %{
          steps: debug_steps,
          total_repairs: length(context1.repairs),
          processing_time_us: end_time - start_time,
          error_at_layer: :layer1
        }

        {:error, reason, debug_info}

      {output1, context1, debug_steps} ->
        # Layer 2: Structural Repair
        case process_layer_with_debug(StructuralRepair, output1, context1, debug_steps, :layer2) do
          {{:error, reason}, context2, debug_steps} ->
            end_time = System.monotonic_time(:microsecond)

            debug_info = %{
              steps: debug_steps,
              total_repairs: length(context2.repairs),
              processing_time_us: end_time - start_time,
              error_at_layer: :layer2
            }

            {:error, reason, debug_info}

          {output2, context2, debug_steps} ->
            # Layer 3: Syntax Normalization
            case process_layer_with_debug(
                   SyntaxNormalization,
                   output2,
                   context2,
                   debug_steps,
                   :layer3
                 ) do
              {{:error, reason}, context3, debug_steps} ->
                end_time = System.monotonic_time(:microsecond)

                debug_info = %{
                  steps: debug_steps,
                  total_repairs: length(context3.repairs),
                  processing_time_us: end_time - start_time,
                  error_at_layer: :layer3
                }

                {:error, reason, debug_info}

              {output3, context3, debug_steps} ->
                # Layer 4: Validation
                case process_layer_with_debug(Validation, output3, context3, debug_steps, :layer4) do
                  {{:error, reason}, final_context, debug_steps} ->
                    end_time = System.monotonic_time(:microsecond)

                    debug_info = %{
                      steps: debug_steps,
                      total_repairs: length(final_context.repairs),
                      processing_time_us: end_time - start_time,
                      error_at_layer: :layer4
                    }

                    {:error, reason, debug_info}

                  {output4, final_context, debug_steps} ->
                    # Check the last step to see if validation succeeded or was skipped
                    last_step = List.last(debug_steps)
                    end_time = System.monotonic_time(:microsecond)

                    debug_info = %{
                      steps: debug_steps,
                      total_repairs: length(final_context.repairs),
                      processing_time_us: end_time - start_time
                    }

                    case last_step.status do
                      :processed ->
                        # Layer 4 processed and validated successfully, output4 is parsed JSON
                        {:ok, output4, debug_info}

                      :skipped ->
                        # Layer 4 skipped, meaning validation failed, but let's add some debug info
                        debug_info_with_error =
                          Map.merge(debug_info, %{
                            error_at_layer: :layer4,
                            final_json_string:
                              if(is_binary(output4),
                                do: String.slice(output4, 0, 500) <> "...",
                                else: inspect(output4)
                              ),
                            json_validation_error: "Jason.decode failed on the repaired JSON"
                          })

                        {:error,
                         "Could not repair JSON - all layers processed but validation failed",
                         debug_info_with_error}

                      _ ->
                        {:error, "Unexpected layer 4 status: #{last_step.status}",
                         Map.put(debug_info, :error_at_layer, :layer4)}
                    end
                end
            end
        end
    end
  end

  @spec process_layer_with_debug(atom(), binary(), map(), list(), atom()) ::
          {binary() | json_value(), map(), list(map())}
          | {{:error, String.t()}, map(), list(map())}
  defp process_layer_with_debug(layer_module, input, context, debug_steps, layer_name) do
    layer_start_time = System.monotonic_time(:microsecond)
    input_size = if is_binary(input), do: byte_size(input), else: 0
    repairs_before = length(context.repairs)

    # Remove debug-specific fields from context before passing to layer
    clean_context = Map.drop(context, [:debug_steps])
    result = layer_module.process(input, clean_context)

    layer_end_time = System.monotonic_time(:microsecond)
    layer_time = layer_end_time - layer_start_time

    case result do
      {:ok, output, new_context} ->
        output_size = if is_binary(output), do: byte_size(output), else: 0
        repairs_after = length(new_context.repairs)
        new_repairs = Enum.drop(new_context.repairs, repairs_before)

        step_info = %{
          layer: layer_name,
          status: :processed,
          input_size: input_size,
          output_size: output_size,
          repairs: new_repairs,
          repair_count: repairs_after - repairs_before,
          processing_time_us: layer_time
        }

        {output, new_context, debug_steps ++ [step_info]}

      {:continue, output, new_context} ->
        output_size = if is_binary(output), do: byte_size(output), else: 0
        repairs_after = length(new_context.repairs)
        new_repairs = Enum.drop(new_context.repairs, repairs_before)

        step_info = %{
          layer: layer_name,
          status: :skipped,
          input_size: input_size,
          output_size: output_size,
          repairs: new_repairs,
          repair_count: repairs_after - repairs_before,
          processing_time_us: layer_time
        }

        {output, new_context, debug_steps ++ [step_info]}

      {:error, reason} ->
        step_info = %{
          layer: layer_name,
          status: :error,
          input_size: input_size,
          error: reason,
          processing_time_us: layer_time
        }

        {{:error, reason}, context, debug_steps ++ [step_info]}
    end
  end
end
