# Windows CI Examples for JsonRemedy
#
# Highlights the new Windows job in the GitHub Actions matrix and how to
# reproduce the steps locally on a Windows machine.
#
# Run with: mix run examples/windows_ci_examples.exs

defmodule WindowsCIExamples do
  @moduledoc """
  Useful helpers for verifying JsonRemedy's Windows CI coverage:
  - Confirms the workflow includes a `windows-2022` runner with PowerShell.
  - Prints the exact commands the CI executes so contributors can mirror them.
  """

  @workflow_path ".github/workflows/elixir.yaml"

  def run_all_examples do
    IO.puts("=== JsonRemedy Windows CI Examples ===\n")

    example_1_verify_windows_job()
    example_2_windows_reproduction_steps()

    IO.puts("\n=== Finished Windows CI examples! ===")
  end

  defp example_1_verify_windows_job do
    IO.puts("Example 1: Verify Windows job exists in CI workflow")
    IO.puts("===================================================")

    workflow = File.read!(@workflow_path)
    windows_job_present = String.contains?(workflow, "runs-on: windows-2022")
    uses_pwsh = String.contains?(workflow, "shell: pwsh")

    IO.puts("Windows runner configured? #{windows_job_present}")
    IO.puts("PowerShell shell configured? #{uses_pwsh}")
    IO.puts("\n" <> String.duplicate("-", 80) <> "\n")
  end

  defp example_2_windows_reproduction_steps do
    IO.puts("Example 2: Commands executed on the Windows runner")
    IO.puts("==================================================")

    commands = [
      "mix deps.get",
      "mix compile --warnings-as-errors",
      "mix test"
    ]

    Enum.each(commands, fn command ->
      IO.puts("pwsh> #{command}")
    end)

    IO.puts(
      "\nTip: Run the commands above inside a PowerShell session after installing Elixir via asdf or the official installer."
    )

    IO.puts("\n" <> String.duplicate("-", 80) <> "\n")
  end
end

WindowsCIExamples.run_all_examples()
