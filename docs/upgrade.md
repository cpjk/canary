# Upgrade guides

## Upgrading from Canary 1.2.0 to 2.0.0

### Update Your Non-ID Actions

> Since 2.0.0, the `:persisted` and `:non_id_actions` options have been deprecated and will be removed in Canary 2.1.0.

You need to update plug calls. Using `:authorize_resource` for actions where there is no actual load action is more explicit.

Let's assume you currently have the following plug call:
```elixir
  plug :load_and_authorize_resource,
    model: Network,
    non_id_actions: [:index, :create, :new],
    preload: [:hypervisor]
```

Now let's break it apart:
```elixir
  plug :authorize_resource,
    model: Network,
    only: [:index, :create, :new],
    required: false

  plug :load_and_authorize_resource,
    model: Network,
    except: [:index, :create, :new],
    preload: [:hypervisor]
```

For non-ID actions, there is a separate plug for authorization. The `required: false` option marks the resource as optional during authorization checks, and the model module name is used. Essentially, this is how :non_id_actions worked.
For actions other than `:index`, `:create`, and `:new`, it will load and authorize resources as usual.
To load all resources in the `:index` action, you can set up a plug or add the load function directly in `index/2`.

```elixir
  # using a plug

  plug :load_all_resources when action in [:index]
  defp load_all_resources(conn, _opts) do
    assign(:networks, Hypervisors.list_hypervisor_networks(hypervisor))
  end

  # directly in the controller action

  def index(conn, _params) do
    networks = Hypervisors.list_hypervisor_networks(hypervisor)
    render(conn, "index.html", networks: networks)
  end
```

### Remove `:persisted` option

With the [update non-id action](#update-your-non-id-actions) the `:persisted` is no longer required.