# Getting Started

This guide introduces **Canary**, an authorization library for **Elixir** applications using `Plug` and `Phoenix.LiveView`. It restricts resource access based on user permissions and automatically loads and assigns resources.

Canary provides three primary functions to be used as *plugs* or *LiveView hooks* to manage resources:

- `load_resource`
- `authorize_resource`
- `load_and_authorize_resource`

## Glossary

### Subject

The key name used to fetch the subject from `assigns`. This subject is passed to `Canada.Can` to evaluate permissions. By default, it is `:current_user`.

To configure this in your module:

```elixir
config :canary, current_user: :user
```

You can override this setting per plug/mounted hook by specifying `:current_user`.

### Action

For **Phoenix applications and Plug-based pages**, Canary determines the action automatically from `conn.private.phoenix_action`. In **non-Phoenix applications**, or when overriding Phoenix's default action behavior, set `conn.assigns.canary_action` with an atom specifying the action.

For **LiveView**:

- In `handle_params`, Canary uses `socket.assigns.live_action`.
- In `handle_event`, Canary uses the `event_name` (converted from a string to an atom for consistency).

Actions can be limited using `:only` or `:except` options; otherwise, they apply to all actions.

### Resource
For `load_resource` and `load_and_authorize_resource`, Canary checks if the resource is already assigned. If not, it fetches the resource from the repository using:

- `:id_name` from `params` (default: `"id"`).
- `:id_field` in the struct (default: `:id`).

By default, **a resource is required**. That means the resource must be present in `conn.assigns` or `socket.assigns`. It's fetched using the `:model` name, which can be overridden with the `:as` option.

If it cannot be found, an error is handled. To make it optional, set `:required` to `false`. In this case, the resource module name is used instead of a loaded struct.

You can also use `:preload` to preload associations. See `Ecto.Query.preload/3` for more details.

For `authorize_resource`, the resource must be present in `conn.assigns` or `socket.assigns`. By default, it fetches the resource using the `:model` name, which can be overridden with the `:as` option.

### Load Resource

Loads a resource from the database using the specified **Ecto repo** and model. It assigns the result to `assigns.<resource_name>`, where `resource_name` is inferred from the model.

### Authorize Resource

Checks if the **subject** can perform a given action on a resource. The result (`true`/`false`) is assigned to `assigns.authorized`. The developer decides how to handle this result.

### Load and Authorize Resource

A combination of **Load Resource** and **Authorize Resource** in a single function.

## Configuration

To use Canary, you need to configure it in `config/config.exs`. All settings, except for `:repo`, can be overridden when using the plug or hook.

### Available Configuration Options

| Name | Description | Example |
| --- | --- | --- |
| `:repo` | The Repo module used in your application. | `YourApp.Repo` |
| `:current_user` | The key name used to fetch the user from assigns. This value will be used as the `subject` for `Canada.Can` to evaluate permissions. Defaults to `:current_user`. | `:current_member` |
| `:error_handler` | A module that implements the `Canary.ErrorHandler` behavior. It is used to handle `:not_found` and `:unauthorized` errors. Defaults to `Canary.DefaultHandler`. | `YourApp.ErrorHandler` |

### Deprecated Options

| Name | Description | Example |
| --- | --- | --- |
| `:not_found_handler` | A `{mod, fun}` tuple for handling not found errors. | `{YourApp.ErrorHandler, :handle_not_found}` |
| `:unauthorized_handler` | A `{mod, fun}` tuple for handling unauthorized errors. | `{YourApp.ErrorHandler, :handle_unauthorized}` |

> #### Info {: .info}
>
> The `:error_handler` option should be used instead of separate handlers for `:not_found` and `:unauthorized` errors.
> Handlers can still be overridden using plug or `mount_canary` options.

### Example Configuration

```elixir
config :canary,
  repo: YourApp.Repo,
  current_user: :current_user,
  error_handler: YourApp.ErrorHandler
```

### Overriding configuration

#### Authorize different subject
Sometimes, you may need to perform authorization for a different subject. You can override `:current_user` by passing options to the plug or hook.

<!-- tabs-open -->
### Conn Plugs
```elixir
import Canary.Plugs

plug :load_and_authorize_resource,
  model: Team,
  current_user: :current_member
```

With this override, the authorization check will use `conn.assigns.current_member` as the subject.


### LiveView Hooks
```elixir
use Canary.Hooks

mount_canary :load_and_authorize_resource,
  on: :handle_event,
  current_user: :current_member,
  model: Team
```

With this override, the authorization check for the `:handle_event` stage hook will use `socket.assigns.current_member` as the subject.
<!-- tabs-close -->


### Different error handler

If you want to override the global Canary error handler, you can override one of the functions: `:not_found_handler` or `:unauthorized_handler`.

<!-- tabs-open -->
### Conn Plugs
```elixir
plug :load_and_authorize_resource,
  model: Team,
  current_user: :current_member,
  not_found_handler: {CustomErrorHandler, :custom_not_found_handler},
  unauthorized_handler: {CustomErrorHandler, :custom_unauthorized_handler}
```

### LiveView Hooks
```elixir
use Canary.Hooks

mount_canary :load_and_authorize_resource,
  model: Team,
  current_user: :current_member,
  only: [:special_action]
  unauthorized_handler: {CustomErrorHandler, :special_unauthorized_handler}
```
<!-- tabs-close -->

The error handler should implement the `Canary.ErrorHandler` behavior.
Refer to the default implementation in `Canary.DefaultHandler`.

## Canary options
Canary Plugs and Hooks use the same configuration options.

### Available Options

| Name | Description | Example |
| --- | --- | --- |
| `:model` | The model module name used in your app. **Required** | `Post` |
| `:only` | Specifies the actions for which the plug/hook is enabled. | `[:show, :edit, :update]` |
| `:except` | Specifies the actions for which the plug/hook is disabled. | `[:delete]` |
| `:current_user` | The key name used to fetch the user from assigns. This value will be used as the `subject` for `Canada.Can` to evaluate permissions. Defaults to `:current_user`. Applies only to `authorize_resource` or `load_and_authorize_resource`. | `:current_member` |
| `:on` | Specifies the LiveView lifecycle stages where the hook should be attached. Defaults to `:handle_params`. **Available only in Canary.Hooks** | `[:handle_params, :handle_event]` |
| `:as` | Specifies the key name under which the resource will be stored in assigns. | `:team_post` |
| `:id_name` | Specifies the name of the ID in params. *Defaults to `"id"`*. | `:post_id` |
| `:id_field` | Specifies the database field name used to search for the `id_name` value. *Defaults to `"id"`*. | `:post_id` |
| `:required` | Determines if the resource is required. If not found, it triggers a not found error. *Defaults to `true`*. | `false` |
| `:not_found_handler` | A `{mod, fun}` tuple that overrides the default error handler for not found errors. | `{YourApp.ErrorHandler, :custom_handle_not_found}` |
| `:unauthorized_handler` | A `{mod, fun}` tuple that overrides the default error handler for unauthorized errors. | `{YourApp.ErrorHandler, :custom_handle_unauthorized}` |

### Deprecated Options

| Name | Description | Example |
| --- | --- | --- |
| `:non_id_actions` | Additional actions for which Canary will authorize based on the model name. | `[:index, :new, :create]` |
| `:persisted` | Forces the resource to always be loaded from the database. Defaults to `false`. **Available only in Canary.Plugs** | `true` |

### Examples

```elixir
  plug :load_and_authorize_resource,
    current_user: :current_member,
    model: Machine,
    preload: [:plan, :networks, :distribution, :job, ipv4: [:ip_pool], hypervisor: :region]

  plug :load_resource,
    model: Hypervisor,
    id_name: "hypervisor_id",
    only: [:new, :create],
    preload: [:region, :hypervisor_type, machines: [:networks, :plan, :distribution]],

  plug :load_and_authorize_resource,
    model: Hypervisor,
    preload: [
      :region,
      :hypervisor_type,
      machines:
        {Hypervisors.preload_active_machines, [:plan, :distribution, :hypervisor, :networks]}
    ]

  mount_canary :authorize_resource,
    on: [:handle_params, :handle_event],
    current_user: :current_member,
    model: Machine,
    only: [:index, :new],
    required: false

  mount_canary :load_and_authorize_resource,
    on: [:handle_event],
    current_user: :current_member,
    model: Machine,
    only: [:start, :stop, :restart, :poweroff]
```

## Plug and Hooks


`Canary.Plugs` and `Canary.Hooks` should work the same way in most cases, providing a unified approach to authorization for both Plug-based controllers and LiveView.

- **Shared Functionality:**
  Both Plugs and Hooks allow for resource loading and authorization using similar configuration options. This ensures consistency across different parts of your application.

- **Differences:**
  - `Canary.Plugs` is designed for use in traditional Phoenix controllers and pipelines.
  - `Canary.Hooks` is specifically built for LiveView and integrates with lifecycle events such as `:handle_params` and `:handle_event`.

- **Configuration Compatibility:**
  Most options, such as `:model`, `:current_user`, `:only`, `:except`, and error handlers, function identically in both Plugs and Hooks. However, `Canary.Hooks` includes the `:on` option, allowing you to specify which LiveView lifecycle stage the authorization should run on.

By keeping their behavior aligned, Canary ensures a seamless developer experience, whether you're working with traditional controller-based actions or real-time LiveView interactions.
### Authorize Resource

The `authorize_resource` function checks whether the subject, typically stored in `assigns` under `:current_user`, is authorized to access a given resource. If the `:current_user` is not authorized, it sets `assigns.authorized` to `false` and calls the `handle_unauthorized/1` function from the `:error_handler` module configured in `config.exs` or the `:unauthorized_handler` specified in the options.

#### Authorization Logic

The authorization check is performed using the `can?/3` function from the `Canada.Can` protocol implemeted for `subject`:

```elixir
can?(subject, action, resource)
```

where:

1. **Subject** – The entity being authorized, typically fetched from `assigns.current_user`.
   - By default, Canary looks for `:current_user`.
   - This key can be overridden via the `opts` or globally in `Application.get_env(:canary, :current_user, :current_user)`.

2. **Action** – The current action being performed.

3. **Resource** – The resource being accessed.
   - If the resource is already loaded, it is taken from `assigns`.
   - If the resource is not loaded and not required, the model name is used instead.

#### Example Usage

```elixir
# Replace `plug` with `mount_canary` for LiveView Hooks
plug :authorize_resource,
  current_user: :current_member,
  model: Event,
  as: :public_event
```

In this example:

1. The `authorize_resource` function checks whether `:current_member` (instead of the default `:current_user`) is authorized to access the `Event` resource.
2. The resource is expected to be available in `assigns.public_event`.
3. If the user is unauthorized, `assigns.authorized` is set to false, and the `unauthorized_handler` is triggered.

### Load Resource

The `load_resource` function fetches a resource based on an ID provided in `params` and assigns it to `assigns`. By default, it uses the `"id"` key from `params` and retrieves the resource from the database using the `:id` field of the model specified in `opts[:model]`. The loaded resource is stored under `assigns` using a key derived from the model module name.

#### Customizing the Load Behavior

You can modify the default behavior with the following options:

- **`:id_name`** – Override the default `"id"` param key.
- **`:id_field`** – Change the field used to query the resource in the database.
- **`:as`** – Override the default `assigns` key where the resource is stored.
- **`:required`** - When set to `false` it will assign `nil` instad calling the `not_found_handler`.

#### Example Usage

```elixir
# Replace `plug` with `mount_canary` for LiveView Hooks
plug :load_resource,
  model: Event,
  as: :public_event,
  id_name: "uuid",
  id_field: :uuid,
  required: false
```

In this example:

1. `load_resource` fetches the `"uuid"` from `params`.
2. It queries `Event` using the `:uuid` field in the database.
3. The result is assigned to `assigns.public_event`.
4. If no matching `Event` is found, `assigns.public_event` will be set to `nil`.

To trigger the `not_found_handler` when the resource is missing, ensure the `:required` flag is **not explicitly set to** `false` (it defaults to `true`).


### Load and Authorize Resource

The `load_and_authorize_resource` function combines two operations:

1. **Loading the Resource** – Fetches the resource based on an ID from `params` and assigns it to `assigns`, similar to `load_resource`.
2. **Authorizing the Resource** – Checks whether the subject (by default, `:current_user`) is authorized to access the resource, using `authorize_resource`.

This function ensures that resources are both retrieved and access-controlled within a single step.

> #### Error handler order {: .info}
>
> If both `:unauthorized_handler` and `:not_found_handler` are specified for `load_and_authorize_resource`, and the request meets the criteria for both, the `:unauthorized_handler` will be called first.


## Non-ID Actions

For actions that do not require loading a specific resource (such as `:index`, `:new`, and `:create`), use `:authorize_resource` instead of `:load_resource` or `:load_and_authorize_resource`.
Ensure that these functions are limited to actions where resource loading is necessary.

By default, the `:required` option is set to `true`, meaning that if the resource cannot be found in the repository, the `not_found_handler` will be called.
Setting `:required` to `false` allows the resource to be assigned as `nil`, in which case the model module name will be used as the resource when calling `can?/3`.

### Example Usage

```elixir
plug :authorize_resource,
  model: Post,
  only: [:index, :new, :create],
  required: false

plug :load_and_authorize_resource,
  model: Post,
  except: [:index, :create, :new]
```

### Loading All Resources in `:index` Action
If you need to load multiple resources for the `:index` action, you can either use a plug or load the resources directly within the `index/2` controller action.

#### Option 1: Using a Plug
```elixir
plug :load_all_resources when action in [:index]

defp load_all_resources(conn, _opts) do
  assign(conn, :posts, Posts.list_posts())
end
```

#### Option 2: Loading Directly in the Controller Action
```elixir
def index(conn, _params) do
  posts = Posts.list_posts()
  render(conn, "index.html", posts: posts)
end
```

## Nested Resources

Sometimes, you need to load and authorize a parent resource when dealing with nested relationships—such as when creating a child resource or listing all children of a parent. With the default `:required` set to true, if the parent resource is not found, the `not_found_handler` will be called.

### Example Usage

When loading and authorizing a `Post` resource that `has_many` `Comment` resources:

```elixir
# Load and authorize the parent (Post)
plug :load_and_authorize_resource,
  model: Post,
  id_name: "post_id",
  only: [:create_comment]

# Authorize action the child (Comment)
plug :authorize_resource,
  model: Comment,
  only: [:create_comment, :save_comment],
  required: false
```

#### Explanation

1. The first plug loads and authorizes the parent `Post` resource using the `post_id` from `params` in the URL (`/posts/:post_id/comments`).
   - The `:required` option ensures that if the Post is missing, the `not_found_handler` is called.
2. The second plug authorizes actions on the child `Comment` resource.
  - Since this is a **non-ID action**, `authorize_resource` is used.
  - The `Comment` module name is passed as the resource to `can?/3` since no specific `Comment` does not exists yet.

This approach ensures that authorization is enforced correctly in nested resource scenarios.

## Defining Permissions

To perform authorization checks, you need to implement the [`Canada.Can` protocol](https://github.com/jarednorman/canada) for each subject that requires permission validation.
By default, Canary uses `:current_user` from Plug or LiveView assigns as the subject.

### Example: Defining Permissions for an Authenticated User

Assume your application has a `User` module for authentication.
You can define permissions in `lib/abilities/user.ex`:

```elixir
defimpl Canada.Can, for: User do
  # Super admin can do everything
  def can?(%User{role: "superadmin"}, _action, _resource), do: true

  # Post owner can view and modify their own posts
  def can?(%User{id: user_id}, action, %Post{user_id: user_id})
    when action in [:show, :edit, :update], do: true

  # Deny all other actions by default
  def can?(%User{id: user_id}, _, _), do: false
end
```

### Handling Anonymous Users

If the subject (`:current_user` in assigns) is `nil`, and the authorization check is performed then `can/3` will be performed against `Atom`.

For anonymous users, define permissions, for example: `lib/abilities/anonymous.ex`:
```elixir
defimpl Canada.Can, for: Atom do
  # Allow anonymous users to register
  def can?(nil, :new, User), do: true
  def can?(nil, :create, User), do: true
  def can?(nil, :confirm, User), do: true

  # Allow anonymous users to create sessions
  def can?(nil, :new, Session), do: true
  def can?(nil, :create, Session), do: true

  # Deny all other actions
  def can?(_, _action, _model), do: false
end
```

Defining permissions for `Atom` and `nil` subjects is optional.
If your application enforces authentication using a plug like `:require_authenticated_user` in the router pipeline, this may not be necessary.


## Error handling

### Handling Unauthorized Actions

By default, when subject is unauthorized to access an action, Canary sets `assigns.authorized` to `false`.
However, you can configure a custom handler function to be called when authorization fails.
Canary will pass the `Plug.Conn` or `Phoenix.LiveView.Socket` to the specified function, which should accept `conn` or `socket` as its only argument and return a `Plug.Conn` or tuple `{:halt, socket}`.

The error handler should implement the `Canary.ErrorHandler` behavior.
Refer to the default implementation in `Canary.DefaultHandler`.

For example, to have Canary call `ErrorHandler.handle_unauthorized/1`:

```elixir
config :canary, error_handler: ErrorHandler
```

> #### LiveView Hook handlers
>
> In LiveView, the error handler should return `{:halt, socket}`.
> For `handle_params`, it should also perform a redirect.


### Handling Resource Not Found

By default, when a resource is not found, Canary sets the resource in `assigns` to `nil`.
Similar to unauthorized action handling, you can configure a function that Canary will call when a resource is missing. This function will receive the `conn` (for Plugs) or `socket` (for LiveView).

```elixir
config :canary, error_handler: ErrorHandler
```

### Overriding Handlers Per Action

You can specify custom handlers per action using `opts` in the `plug` or `mount_canary` call.
These handlers will override any globally configured error handlers.

<!-- tabs-open -->

### Conn Plugs

```elixir
plug :load_and_authorize_resource Post,
  unauthorized_handler: {Helpers, :handle_unauthorized},
  not_found_handler: {Helpers, :handle_not_found}
```

> **Tip:** If you want to stop request handling after the handler function executes (e.g., for a redirect),
> be sure to call `Plug.Conn.halt/1` within your handler:

```elixir
def handle_unauthorized(conn) do
  conn
  |> put_flash(:error, "You can't access that page!")
  |> redirect(to: "/")
  |> halt()
end
```

### LiveView Hooks

```elixir
mount_canary :load_and_authorize_resource Post,
  unauthorized_handler: {Helpers, :handle_unauthorized},
  not_found_handler: {Helpers, :handle_not_found}
```

> **Tip:** If you want to stop request handling after the handler function executes (e.g., for a redirect),
> be sure to call `Plug.Conn.halt/1` within your handler:

```elixir
def handle_unauthorized(socket) do
  {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
end
```
<!-- tabs-close -->

> #### Error handler order {: .info}
>
> If both an `:unauthorized_handler` and a `:not_found_handler` are specified for `load_and_authorize_resource`,
> and the request meets the criteria for both, the `:unauthorized_handler` will be called first.