ExUnit.start()

# Configure ExUnit for our testing needs
ExUnit.configure(
  exclude: [:skip, :pending],
  formatters: [ExUnit.CLIFormatter]
)

# Define test tags
ExUnit.configure(
  exclude: [
    # Skip performance tests by default
    :performance,
    # Skip property tests by default
    :property,
    # Skip slow tests by default
    :slow,
    # Run integration tests explicitly
    :integration
  ]
)
