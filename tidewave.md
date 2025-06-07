You're right that the documentation shows Phoenix-specific setup, but you can absolutely use Tidewave in a non-Phoenix Elixir project! You just need to set up a basic HTTP server to serve the MCP endpoint.

Here are a few approaches to get Tidewave working without Phoenix:

## Option 1: Use Plug with Bandit (Recommended)

Add these dependencies to your `mix.exs`:

```elixir
def deps do
  [
    {:tidewave, "~> 0.1", only: :dev},
    {:plug, "~> 1.14"},
    {:bandit, "~> 1.0", only: :dev}
  ]
end
```

Create a simple HTTP server module:

```elixir
# lib/my_app/dev_server.ex
defmodule MyApp.DevServer do
  use Plug.Router

  plug :match
  plug :dispatch

  # Mount Tidewave at the root - it will handle /tidewave/mcp
  plug Tidewave

  match _ do
    send_resp(conn, 404, "Not found")
  end

  def start_link(opts \\ []) do
    port = opts[:port] || 4000
    
    Bandit.start_link(
      plug: __MODULE__,
      port: port,
      scheme: :http
    )
  end
end
```

Then start it in your application supervisor or manually:

```elixir
# In your application.ex
def start(_type, _args) do
  children = [
    # your other children...
    {MyApp.DevServer, port: 4000}  # only in dev
  ]
  
  Supervisor.start_link(children, strategy: :one_for_one)
end
```

## Option 2: Use Cowboy Directly

If you prefer Cowboy:

```elixir
def deps do
  [
    {:tidewave, "~> 0.1", only: :dev},
    {:plug, "~> 1.14"},
    {:plug_cowboy, "~> 2.6", only: :dev}
  ]
end
```

```elixir
# Same router as above, but start with:
def start_link(opts \\ []) do
  port = opts[:port] || 4000
  
  Plug.Cowboy.http(__MODULE__, [], port: port)
end
```

## Option 3: Conditional Development Server

You can make this only run in development:

```elixir
# lib/my_app/application.ex
def start(_type, _args) do
  children = base_children() ++ dev_children()
  
  Supervisor.start_link(children, strategy: :one_for_one)
end

defp base_children do
  [
    # your regular app children
  ]
end

defp dev_children do
  if Mix.env() == :dev and Code.ensure_loaded?(Tidewave) do
    [{MyApp.DevServer, port: 4000}]
  else
    []
  end
end
```

## Configuration

You can configure Tidewave in the plug call:

```elixir
plug Tidewave, 
  allowed_origins: ["http://localhost:3000"],
  allow_remote_access: false,
  tools: [exclude: [:some_tool]]
```

After setting this up, your MCP endpoint will be available at `http://localhost:4000/tidewave/mcp` just like with Phoenix, and you can configure your editor accordingly.

This approach gives you all the Tidewave functionality without needing Phoenix's full framework overhead!

