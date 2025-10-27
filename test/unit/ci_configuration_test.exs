defmodule JsonRemedy.CIConfigurationTest do
  use ExUnit.Case, async: true

  @workflow_path ".github/workflows/elixir.yaml"

  test "workflow defines a Windows test job" do
    workflow = File.read!(@workflow_path)

    assert workflow =~ "runs-on: windows-2022"
    assert workflow =~ "shell: pwsh"
    assert workflow =~ "mix test"
  end
end
