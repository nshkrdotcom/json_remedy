defmodule JsonRemedy do
  @moduledoc """
  Repairs malformed JSON strings.

  This library provides functions to parse and repair JSON data that may be
  syntactically incorrect, often the case with output from Large Language Models (LLMs).
  """

  alias JsonRemedy.Parser

  @type json_term :: map | list | String.t() | number | boolean | nil
  @type repair_opts :: [logging: boolean, stream_stable: boolean]
  @type repair_result :: {:ok, json_term} | {:error, String.t()}
  @type repair_result_with_log :: {:ok, json_term, [map]} | {:error, String.t()}

  @doc """
  Repairs a JSON string and returns the corresponding Elixir term.

  It first attempts to parse the string with `Jason`. If that fails, it uses
  its internal repair parser.

  ## Options

    * `:logging` - If `true`, returns `{:ok, term, logs}` on success. Defaults to `false`.
    * `:stream_stable` - If `true`, enables more stable parsing for incomplete streams. Defaults to `false`.

  ## Examples

      iex> JsonRemedy.repair("{'key': 'value'}")
      {:ok, %{"key" => "value"}}

      iex> JsonRemedy.repair("[1, 2, 3,]")
      {:ok, [1, 2, 3]}

      iex> JsonRemedy.repair("invalid", logging: true)
      {:ok, "", [%{context: "invalid", text: "Skipping extraneous starting character."}]}
  """
  @spec repair(String.t(), repair_opts) :: repair_result() | repair_result_with_log()
  def repair(json_string, opts \\ []) do
    case Jason.decode(json_string) do
      {:ok, term} ->
        handle_success(term, [], Keyword.get(opts, :logging, false))

      {:error, _} ->
        case Parser.parse(json_string, opts) do
          # FIX: Use fully qualified module name to avoid namespace collision.
          {:ok, term, logger} ->
            handle_success(
              term,
              JsonRemedy.Logger.get_logs(logger),
              Keyword.get(opts, :logging, false)
            )

          {:error, reason, _} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Repairs a JSON string and returns a valid JSON string.
  """
  @spec repair_to_string(String.t(), repair_opts) :: {:ok, String.t()} | {:error, String.t()}
  def repair_to_string(json_string, opts \\ []) do
    case repair(json_string, opts) do
      {:ok, term} -> Jason.encode(term)
      {:ok, term, _logs} -> Jason.encode(term)
      error -> error
    end
  end

  @doc """
  A drop-in replacement for `Jason.decode!/2`, but with repair capabilities.
  Repairs and decodes a JSON string, raising an error on failure.
  """
  @spec loads!(String.t(), repair_opts) :: json_term
  def loads!(json_string, opts \\ []) do
    case repair(json_string, opts) do
      {:ok, term} -> term
      {:ok, term, _} -> term
      {:error, reason} -> raise "JsonRemedy failed to repair JSON: #{reason}"
    end
  end

  @doc """
  Repairs JSON from a file.
  """
  @spec from_file(Path.t(), repair_opts) :: repair_result() | repair_result_with_log()
  def from_file(path, opts \\ []) do
    case File.read(path) do
      {:ok, content} -> repair(content, opts)
      {:error, reason} -> {:error, "File error: #{:file.format_error(reason)}"}
    end
  end

  defp handle_success(term, logs, logging?) do
    if logging? do
      {:ok, term, logs}
    else
      {:ok, term}
    end
  end
end

