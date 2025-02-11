# Getting started

This guide is an introduction to Canary, an authorization library in Elixir for `Plug` and `Phoenix.LiveView` applications that restricts what resources the current user is allowed to access, and automatically load and assigns resources.

Canary provides three main functions to be used as *plugs* or *LiveView hooks* to load and authorize resource: `load_resource`, `authorize_resource` and `load_and_authorize_resource`

## Glossary

### Subject
It is the key name to fetch from the `assigns`. It will be used as `subject` for `Canada.Can` to evaluate permissions. By default it's set to `:current_user`.

It can be defined in module config with `config :canary, current_user: :user`
This option can be overridden with `:current_user` for each plug / mouted hook.

### Action
For Phoenix applications and Plug based pages, Canary determines the action automatically (from `conn.private.phoenix_action`).
For non-Phoenix applications, or to override the action provided by Phoenix when using it with Plug, simply ensure that `conn.assigns.canary_action` contains an atom specifying the action.

For the LiveView on handle_params it uses `socket.assigns.live_action` as action on handle_event it uses the `event_name` as action.
> Note that the event_name is a string - but in Canary it's converted to an atom for consistency.

Action can be limited by using `:only` or `:except` options, otherwise it will be performed on for actions.

### Resource
For `load_resource` and `load_and_authorize_resource` functions it checks if the resource is already assigned, if not then it fetches it from the repo using `:id_name` form `params` (default `"id"`) and `:id_field` in struct (default `:id`).

If the `:required` is set, then it will handle error when resource is not loaded.

It also supports `:preload` preloading association(s). Please refer to `Ecto.Query.preload/3` for additional informations about preloading associations.

For the `authorize_resource` it expects that resource is available in conn / socket assigns. By default it uses the `:model` name as key to fetch the resoruce. This can be set by using `:as` option. When resource is not set, then the model module name is set as resoiurce.

### Load resource
Loads the resource having the id given in `params["id"]` from the database using the given Ecto repo and model, and assigns the resource to `assigns.<resource_name>`, where resource_name is inferred from the model name.

### Authorize resource
Checks whether or not the `subject` for the request can perform the given action on the given resource and assigns the result (true/false) to `assigns.authorized`. It is up to you to decide what to do with the result.

### Load and authorize resource
Combines boths **Load resource** and **Authorize resource** in one function

## Configuration

In order to use Canary you need to configure it `config/config.exs`. All settings except the `:repo` can be overriden when using the plug or hook.

### Available config options
| Name      | Description |  Example |
| ----------- | ----------- | ----------- |
| `:repo`      | Repo module name used in your app       | `YourApp.Repo` |
| `:current_user`   | Key name to fetch from the assigns. It will be used as `subject` for `Canada.Can` to evaluate permissions. Default set to `:current_user`       | `:current_member` |
| `:error_handler` | Module which implements `Canary.ErrorHandler` behaviour. It will be used to handle `:not_found` and `:unauthorized`. By default set to `Canary.DefaultHandler` | `YourApp.ErrorHandler` |

### Deprecated options
| Name      | Description |  Example |
| ----------- | ----------- | ----------- |
| `:not_found_handler` | `{mod, fun}` tuple  | `{YourApp.ErrorHandler, :handle_not_found}` |
| `:unauthorized_handler` | `{mod, fun}` tuple  | `{YourApp.ErrorHandler, :handle_unauthorized}` |

> #### Info {: .info}
>
> For the module configuration the `:error_handler` should be used instead of separate handler for not found and unauthorized errors. The handleds still can be overritten with plug / mount_canary options.


### Example

```
config :canary,
  repo: YourApp.Repo,
  current_user: :current_user,
  error_handler: YourApp.ErrorHandler
```

### Overriding configuration

#### Authorize different subject
Sometimes there is need to perform authorization for different subject. You can override the `:current_user` with options passed to plug or hook.

<!-- tabs-open -->
### Conn Plugs
```elixir
import Canary.Plugs

plug :load_and_authorize_resource,
  model: Team,
  current_user: :current_member
```

with this override it will perform authorization check using `conn.assings.current_member` as a subject.

### LiveView Hooks
```elixir
use Canary.Hooks

mount_canary :load_and_authorize_resource,
  on: :handle_event,
  current_user: :current_member,
  model: Team
```

with this override it will perform authorization check for the `:handle_event` stage hook using `socket.assigns.current_member` as a subject.
<!-- tabs-close -->


### Different error handler

If you want to override global Canary error handler you can override one of the functions `:not_found_handler` and `:unauthorized_handler`

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

Error handler should implement the `Canary.ErrorHandler` behaviour. Check for the default implementation in `Canary.DefaultHandler`

## Canary options

Canary Plugs and Hooks uses the same configuration options.

### Available opts
| Name      | Description |  Example |
| ----------- | ----------- | ----------- |
| `:model`      | Model module name used in your app  **Required**     | `Post` |
| `:only` | Specifies for which actions plug/hook is enabled | `[:show, :edit, :update]` |
| `:except` |  Specifies for which actions plug/hook is disabled  | `[:delete]` |
| `:current_user`   | Key name to fetch from the assigns. It will be used as `subject` for `Canada.Can` to evaluate permissions. Default set to `:current_user`. Applies only for `authorize_resource` or `load_and_authorize_resource`       | `:current_member` |
| `:on` | Specifies the LiveView lifecycle stages to attach the hook. Default `:handle_params` **Available only in Canary.Hooks** | `[:handle_params, :handle_event]` |
| `:as` | Specifies the resource_name key in assigns | `:team_post` |
| `:id_name` | Specifies the name of the id in params, *defaults to "id"* | `:post_id` |
| `:id_field` | Specifies the name of the ID field in the database for searching :id_name value, *defaults to "id"*. | `:post_id` |
| `:required` | Specifies if the resource is required, when it's not found it will handle not found error, *defaults to true* | false |
| `:not_found_handler` | `{mod, fun}` tuple, it overrides the default error handler for not found error  | `{YourApp.ErrorHandler, :custom_handle_not_found}` |
| `:unauthorized_handler` | `{mod, fun}` tuple, it overrides the default error handler for unauthorized error  | `{YourApp.ErrorHandler, :custom_handle_unauthorized}` |

### Deprecated options
| Name      | Description |  Example |
| ----------- | ----------- | ----------- |
| `:non_id_actions` | Additional actions for which Canary will authorize based on the model name | `[:index, :new, :create]` |
| `:persisted` | Specifies the resource should always be loaded from the database, defaults to false **Available only in Canary.Plugs** | true |

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

`Canary.Plugs` and `Canary.Hooks` should work the same way in most cases.


### Authorize resource

Authorize the subject key from `assigns` - by default `:current_user` - for the given resource. If the `:current_user` is not authorized it will set `assigns.authorized` to `false` and call the `handle_unauthorized/1` from the `:error_handler` module set in config - or `:unauthorized_handler` from opts.

For the authorization check, it uses the `can?/3` function from the `Canada.Can` module -

`can?(subject, action, resource)` where:

1. The subject is the `:current_user` from the socket assigns. The `:current_user` key can be changed in the `opts` or in the `Application.get_env(:canary, :current_user, :current_user)`. By default it's `:current_user`.
2. Current action
3. The resource is the loaded resource from the socket assigns or the model name if the resource is not loaded and not required.

You can find out more in [Glossary](getting-started.md#glossary) and [Canary options](getting-started.md#canary-options)

### Load resource

Load the resource with id given in `params` - by "id" key (default) - and ecto model given by `:id` field form `opts[:model]` into `assigns` by the `resource_name` where it is a Atom generated from the model module name.

Load function can get the param by different key - you can override the default "id" by setting the `:id_name` option.
The `:id` field used to get the resource also might be changed with `:id_field` option.
The `resource_name` can be also overriten with the `:as` option.

For example:
```elixir
# replace plug with mount_canary for LiveView Hooks
plug :load_resource,
  model: Event,
  as: :public_event,
  id_name: "uuid",
  id_field: :uuid
```

The `load_resource` function will try to fetch the "uuid" from `params`, then will try to get `Event` from `repo` by `:uuid` field, and then it will be assigned to the `assigns.public_event`.

The `assigns.public_event` might be set to `nil` if there is no matchin `Event`. If you want to call the `not_found_handler` then you need to set the `:required` flag.

You can check all available [Canary options](getting-started.md#canary-options)

### Load and authorize resource

It combines two other functions - `load_resource` and `authorize_resource`.

> #### Error handler order {: .info}
>
> If both an :unauthorized_handler and a :not_found_handler are specified for load_and_authorize_resource, and the request meets the criteria for both, the :unauthorized_handler will be called first.

## Non-id actions

For the non-id actions where there is no resource to be loaded please use `:authorize_resource` and limit other functions `:load_resource` or `:load_and_authorize_resource` to skip those actions. By default `:required` option is set to true, so when resouce cannot be get from repo the model the `not_found_handler` will be called. Changing `:required` to false will allow to set resource as nil, and then module name will be used as resource for the call to `Canada.can?`.

```elixir
plug :authorize_resource,
  model: Post,
  only: [:index, :new, :create],
  required: false

plug :load_and_authorize_resource,
  model: Post,
  except: [:index, :create, :new]
```

To load all resources on `:index` aciton you can setup plug, or add the load function directly in `index/2`

```elixir
  # with plug

  plug :load_all_resources when action in [:index]
  defp load_all_resources(conn, _opts) do
    assign(:posts, Posts.list_posts())
  end

  # or directly in the controller action

  def index(conn, _params) do
    posts = Posts.list_posts()
    render(conn, "index.html", posts: posts)
  end
```

## Nested resources

Sometimes you need to load and authorize a parent resource when you have a relationship between two resources and you are creating a new one or listing all the children of that parent. By specifying the `:required` option with `true` you can load and/or authorize a nested resource.

If the parent resource is not available then the

For example, when loading and authorizing a `Post` resource which can have one or more `Comment` resources, use

```elixir
# parent
plug :load_and_authorize_resource,
  model: Post,
  id_name: "post_id",
  only: [:create_comment]

# child
plug :authorize_resouce,
  model: Comment,
  only: [:create_comment, :save_comment],
  required: false
```

to load and authorize the parent `Post` resource using the `post_id` in `/posts/:post_id/comments` before you create the `Comment` resource using its parent.
The `:required` option will call `non_found_handler` when the parent resource (`Post`) is not found by given `post_id`.

The second plug will perfom the authorization for non-id action which is `:create_comment` and `:save_commen`. The `Comment` module name will be used as resource for the call to `Canada.can?`.

## Definig permissions

You need to implement [Canada.Can protocol](https://github.com/jarednorman/canada) for each subject on which you want to perform authorization checks.
Default subject is the `:current_user` key taken from Plug / LiveView assigns.

Let's assume that you have `User` module in your app which is used for Autentication.

Permissions for authenticated user, for example `lib/abilities/user.ex`:
```elixir
defimpl Canada.Can, for: User do

  # Super admin can do everything
  def can?(%User{role: "superadmin"}, _action, _resource), do: true

  # Post owner can view and change it
  def can?(%User{id: user_id}, action, %Post{ user_id: user_id })
    when action in [:show, :edit, :update], do: true

  def can?(%User{id: user_id}, _, _), do: false
end
```

When the subject (`:current_user` assigns) is `nil`, and the authorization check is performed then `can/3` will be performed against `Atom`.

Permissions for anonymous users, for example: `lib/abilities/anonymous.ex`:
```elixir
defimpl Canada.Can, for: Atom do
  # Registration
  def can?(nil, :new, User), do: true
  def can?(nil, :create, User), do: true
  def can?(nil, :confirm, User), do: true

  # Session
  def can?(nil, :new, Session), do: true
  def can?(nil, :create, Session), do: true

  def can?(_, _action, _model), do: false
end
```

Although this is optional, as it might not be a valid case if you have plug which requires user for example `:require_authenticated_user` in the router pipeline.

## Error handling

### Handling unauthorized actions

By default, when an action is unauthorized, Canary simply sets `assigns.authorized` to `false`.
However, you can configure a handler function to be called when authorization fails. Canary will pass the `Plug.Conn` to the given function. The handler should accept a `Plug.Conn` as its only argument, and should return a `Plug.Conn`.

For example, to have Canary call `ErrorHandler.handle_unauthorized/1`:

```elixir
config :canary, error_handler: ErrorHandler
```

> #### LiveView Hook handlers
>
> LiveView error handler shoud return `{:halt, socket}`. For the `handle_params` it also should do the redirect.

### Handling resource not found

By default, when a resource is not found, Canary simply sets the resource in `assigns` to `nil`. Like unauthorized action handling , you can configure a function to which Canary will pass the `conn` or `socket` when a resource is not found:

```elixir
config :canary, error_handler: ErrorHandler
```

You can also specify handlers on an individual basis (which will override the corresponding configured handler, if any) by specifying the corresponding `opt` in the plug / mount_canary call:

<!-- tabs-open -->
### Conn Plugs
```elixir
plug :load_and_authorize_resource Post,
  unauthorized_handler: {Helpers, :handle_unauthorized},
  not_found_handler: {Helpers, :handle_not_found}
```

> Tip: If you would like the request handling to stop after the handler function exits, e.g. when redirecting, be sure to call `Plug.Conn.halt/1` within your handler like so:

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

> Tip: If you would like the request handling to stop after the handler function exits, e.g. when redirecting, be sure to call `Plug.Conn.halt/1` within your handler like so:

```elixir
def handle_unauthorized(socket) do
  {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
end
```
<!-- tabs-close -->


> #### Error handler order {: .info}
>
> If both an `:unauthorized_handler` and a `:not_found_handler` are specified for `load_and_authorize_resource`, and the request meets the criteria for both, the `:unauthorized_handler` will be called first.
