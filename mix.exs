defmodule JsonRemedy.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/json_remedy"

  def project do
    [
      app: :json_remedy,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "A blazingly fast Elixir library for repairing malformed JSON using binary pattern matching. Handles LLM outputs, legacy data, and broken JSON with intelligent context-aware fixes.",
      package: package(),
      docs: docs(),
      escript: escript(),
      aliases: [
        test: "test --no-start"
      ],
      dialyzer: [
        plt_add_deps: :apps_direct,
        plt_add_apps: [:mix, :jason],
        flags: [:error_handling, :underspecs]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:benchee, "~> 1.1", only: :dev},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false}
    ]
  end

  defp escript do
    [main_module: JsonRemedy.CLI]
  end

  defp package do
    [
      maintainers: ["nshkrdotcom"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Documentation" => "https://hexdocs.pm/json_remedy"
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "JsonRemedy",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "LICENSE"]
    ]
  end
end
