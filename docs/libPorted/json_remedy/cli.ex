defmodule JsonRemedy.CLI do
  @moduledoc """
  Command-line interface for the JsonRemedy library.
  """

  def main(argv) do
    argv
    |> parse_args()
    |> process_args()
    |> System.stop()
  rescue
    e in [RuntimeError] ->
      IO.puts(:stderr, e.message)
      System.stop(1)
  end

  defp parse_args(argv) do
    switches = [
      inline: :boolean,
      output: :string,
      indent: :integer,
      help: :boolean
    ]

    aliases = [
      i: :inline,
      o: :output,
      h: :help
    ]

    case OptionParser.parse(argv, switches: switches, aliases: aliases) do
      {opts, [filename], []} -> {opts, filename}
      {opts, [], []} -> {opts, :stdin}
      {_, _, [err | _]} -> raise "Invalid argument: #{err}"
      {_opts, [_ | _], _} -> raise "Too many files specified"
    end
  end

  defp process_args({[help: true], _}) do
    print_help()
    0
  end

  defp process_args({opts, source}) do
    input =
      case source do
        :stdin -> IO.read(:all)
        filename -> File.read!(filename)
      end

    case JsonRemedy.repair_to_string(input) do
      {:ok, repaired_json} ->
        pretty_json =
          Jason.decode!(repaired_json)
          |> Jason.encode!(pretty: [indent: String.duplicate(" ", opts[:indent] || 2)])

        handle_output(pretty_json, source, opts)
        0

      {:error, reason} ->
        IO.puts(:stderr, "Error: Failed to repair JSON. Reason: #{reason}")
        1
    end
  end

  # FIX: Changed `_source` to `source` to make the variable available.
  defp handle_output(content, source, opts) when is_list(opts) do
    cond do
      opts[:output] ->
        File.write!(opts[:output], content)

      opts[:inline] && is_binary(source) ->
        File.write!(source, content)

      opts[:inline] ->
        raise "--inline requires a filename, not stdin"

      true ->
        IO.puts(content)
    end
  end

  defp print_help do
    IO.puts("""
    JsonRemedy - A tool to repair broken JSON.

    Usage:
      json_remedy [options] [filename]

    If no filename is provided, reads from stdin.

    Options:
      -i, --inline       Modify the file in-place.
      -o, --output FILE  Write the repaired JSON to FILE.
      --indent N         Set indentation level (default: 2).
      -h, --help         Show this help message.
    """)
  end
end
