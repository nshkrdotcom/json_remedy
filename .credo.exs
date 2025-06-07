%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "src/", "web/", "apps/"],
        excluded: []
      },
      plugins: [],
      requires: [],
      checks: [
        {Credo.Check.Readability.Specs, false}
      ]
    }
  ]
}
