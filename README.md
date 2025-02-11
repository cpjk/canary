Canary
======
[![Actions Status](https://github.com/cpjk/canary/workflows/CI/badge.svg)](https://github.com/runhyve/canary/actions?query=workflow%3ACI)
[![Hex pm](https://img.shields.io/hexpm/v/canary.svg?style=flat)](https://hex.pm/packages/canary)

An authorization library in Elixir for `Plug` and `Phoenix.LiveView` applications that restricts what resources the current user is allowed to access, and automatically load and assigns resources.

Inspired by [CanCan](https://github.com/CanCanCommunity/cancancan) for Ruby on Rails.

[Read the docs](https://hexdocs.pm/canary/2.0.0-dev/)

# Canary 2.0.0

The `master` branch is for the development of Canary 2.0.0. Check out [branch 1.2.x](https://github.com/cpjk/canary/tree/1.2.x) if you are looking Canary 1 (only plug authentication).

## Installation

For the latest master (2.0.0-dev):

```elixir
defp deps do
  {:canary, github: "cpjk/canary"}
end
```

For the latest release:

```elixir
defp deps do
  {:canary, "~> 2.0.0-dev"}
end
```

Then run `mix deps.get` to fetch the dependencies.

## Quick start

Canary provides functions to be used as plugs or LiveView hooks to load and authorize resources:

`load_resource`, `authorize_resource`, `authorize_controller`*, and `load_and_authorize_resource`.

`load_resource` and `authorize_resource` can be used by themselves, while `load_and_authorize_resource` combines them both.

*Available only in plug based authentication*

In order to use Canary, you will need, at minimum:

- A [Canada.Can protocol](https://github.com/jarednorman/canada) implementation (a good place would be `lib/abilities.ex`)

- An Ecto record struct containing the user to authorize in `assigns.current_user` (the key can be customized - [see more](#overriding-the-default-user)).

- Your Ecto repo specified in your `config/config.exs`: `config :canary, repo: YourApp.Repo`

For the plugs just `import Canary.Plugs`. In a Phoenix app the best place would probably be inside `controller/0` in your `web/web.ex`, in order to make the functions available in all of your controllers.

For the liveview hooks just `use Canary.Hooks`. In a Phoenix app the best place would probably be inside `live_view/0` in your `web/web.ex`, in order to make the functions available in all of your controllers.


### load_resource

Loads the resource having the id given in `params["id"]` from the database using the given Ecto repo and model, and assigns the resource to `assigns.<resource_name>`, where `resource_name` is inferred from the model name.

<!-- tabs-open -->
### Conn Plugs example
```elixir
plug :load_resource, model: Project.Post
```

Will load the `Project.Post` having the id given in `conn.params["id"]` through `YourApp.Repo`, and assign it to `conn.assigns.post`.

### LiveView Hooks example
```elixir
mount_canary :load_resource, model: Project.Post
```

Will load the `Project.Post` having the id given in `params["id"]` through `YourApp.Repo`, and assign it to `socket.assigns.post`
<!-- tabs-close -->

### authorize_resource

Checks whether or not the `current_user` for the request can perform the given action on the given resource and assigns the result (true/false) to `assigns.authorized`. It is up to you to decide what to do with the result.

For Phoenix applications, Canary determines the action automatically.
For non-Phoenix applications, or to override the action provided by Phoenix, simply ensure that `assigns.canary_action` contains an atom specifying the action.

For the LiveView on `handle_params` it uses `socket.assigns.live_action` as action, on `handle_event` it uses the event name as action.



In order to authorize resources, you must specify permissions by implementing the [Canada.Can protocol](https://github.com/jarednorman/canada) for your `User` model (Canada is included as a light weight dependency).

### load_and_authorize_resource

Authorizes the resource and then loads it if authorization succeeds. Again, the resource is loaded into `assigns.<resource_name>`.

In the following example, the `Post` with the same `user_id` as the `current_user` is only loaded if authorization succeeds.

## Usage Example

Let's say you have a Phoenix application with a `Post` model, and you want to authorize the `current_user` for accessing `Post` resources.

Let's suppose that you have a file named `lib/abilities.ex` that contains your Canada authorization rules like so:

```elixir
defimpl Canada.Can, for: User do
  def can?(%User{ id: user_id }, action, %Post{ user_id: user_id })
    when action in [:show], do: true

  def can?(%User{ id: user_id }, _, _), do: false
end
```

### Example for Conn Plugs

In your `web/router.ex:` you have:

```elixir
get "/posts/:id", PostController, :show
delete "/posts/:id", PostController, :delete
```

To automatically load and authorize on the `Post` having the `id` given in the params, you would add the following plug to your `PostController`:

```elixir
plug :load_and_authorize_resource, model: Post
```

In this case, on `GET /posts/12` authorization succeeds, and the `Post` specified by `conn.params["id]` will be loaded into `conn.assigns.post`.

However, on `DELETE /posts/12`, authorization fails and the `Post` resource is not loaded.

### Example for LiveView Hooks

In your `web/router.ex:` you have:

```elixir
live "/posts/:id", PostLive, :show
```

and in your PostLive module `web/live/post_live.ex`:

```elixir
defmodule MyAppWeb.PostLive do
  use MyAppWeb, :live_view

  def render(assigns) do
    ~H"""
    Post id: {@post.id}
    <button phx-click="delete">Delete</button>
    """
  end

  def mount(_params, _session, socket), do: {:ok, socket}

  def handle_event("delete", _params, socket) do
    # Do the action
    {:noreply, update(socket, :temperature, &(&1 + 1))}
  end
end
```

To automatically load and authorize on the `Post` having the `id` given in the params, you would add the following hook to your `PostLive`:

```elixir
mount_hook :load_and_authorize_resource, model: Post
```

In this case, once opening `/posts/12` the `load_and_authorize_resource` on `handle_params` stage will be performed. The the `Post` specified by `params["id]` will be loaded into `socket.assigns.post`.

However, when the `delete` event will be triggered, authorization fails and the `Post` resource is not loaded. Socket will be halted.

### Excluding actions

To exclude an action from any of the plugs, pass the `:except` key, with a single action or list of actions.

For example,

Single action form:

```elixir
plug :load_and_authorize_resource, model: Post, except: :show

mount_canary :load_and_authorize_resource, model: Post, except: :show
```

List form:

```elixir
plug :load_and_authorize_resource, model: Post, except: [:show, :create]

mount_canary :load_and_authorize_resource, model: Post, except: [:show, :create]
```

### Authorizing only specific actions

To specify that a plug should be run only for a specific list of actions, pass the `:only` key, with a single action or list of actions.

For example,

Single action form:

```elixir
plug :load_and_authorize_resource, model: Post, only: :show

mount_canary :load_and_authorize_resource, model: Post, only: :show
```

List form:

```elixir
plug :load_and_authorize_resource, model: Post, only: [:show, :create]

mount_canary :load_and_authorize_resource, model: Post, only: [:show, :create]
```

> Note: Having both `:only` and `:except` in opts is invalid. Canary will raise `ArgumentError` "You can't use both :except and :only options"

### Overriding the default user

Globally, the default key for finding the user to authorize can be set in your configuration as follows:

```elixir
config :canary, current_user: :some_current_user
```

In this case, canary will look for the current user record in `assigns.some_current_user`.

The current user key can also be overridden for individual plugs as follows:

```elixir
plug :load_and_authorize_resource, model: Post, current_user: :current_admin

mount_canary :load_and_authorize_resource, model: Post, current_user: :current_admin
```

### Specifying resource_name

To specify the name under which the loaded resource is stored, pass the `:as` flag in the plug declaration.

For example,

```elixir
plug :load_and_authorize_resource, model: Post, as: :new_post

mount_canary :load_and_authorize_resource, model: Post, as: :new_post
```

will load the post into `assigns.new_post`

### Preloading associations

Associations can be preloaded with `Repo.preload` by passing the `:preload` option with the name of the association:

```elixir
plug :load_and_authorize_resource, model: Post, preload: :comments

mount_canary :load_and_authorize_resource, model: Post, preload: :comments
```

### Non-id actions

To authorize actions where there is no loaded resource, the resource passed to the `Canada.Can` implementation should be the module name of the model rather than a struct.

To authorize such actions use `authorize_resource` plug with `required: false` option

```elixir
plug :authorize_resource, model: Post, only: [:index, :new, :create], required: false

mount_canary :authorize_resource, model: Post, only: [:index, :new, :create], required: false
```

For example, when authorizing access to the `Post` resource, you should use

```elixir
def can?(%User{}, :index, Post), do: true
```

instead of

```elixir
def can?(%User{}, :index, %Post{}), do: true
```

> ### Deprecated {: .warning}
>
> The `:non_id_actions` is deprecated as of 2.0.0-dev and will be removed in Canary 2.1.0
> Please follow the [Upgrade guide to 2.0.0](docs/upgrade.md#upgrading-from-canary-1-2-0-to-2-0-0) for more details.

### Nested associations

Sometimes you need to load and authorize a parent resource when you have
a relationship between two resources and you are creating a new one or
listing all the children of that parent. Depending on your authorization
model you migth authorize against the parent resource or against the child.

```elixir
defmodule MyAppWeb.CommentController do

  plug :load_and_authorize_resource,
    model: Post,
    id_name: "post_id",
    only: [:new_comment, :create_comment]

  # get /posts/:post_id/comments/new
  def new_comment(conn, _params) do
    # ...
  end

  # post /posts/:post_id/comments
  def new_comment(conn, _params) do
    # ...
  end
end
```

It will authorize using `Canada.Can` with following arguments:
1. subject is `conn.assigns.current_user`
2. action is `:new_comment` or `:create_comment`
3. resource is `%Post{}` with `conn.params["post_id"]`

Thanks to the `:requried` set to true by default this plug will call `not_found_handler` if the `Post` with given `post_id` does not exists.
If for some reason you want to disable it, set `required: false` in opts.

> ### Deprecated {: .warning}
>
> The `:persisted` is deprecated as of 2.0.0-dev and will be removed in Canary 2.1.0
> Please follow the [Upgrade guide to 2.0.0](docs/upgrade.md#upgrading-from-canary-1-2-0-to-2-0-0) for more details.

### Implementing Canada.Can for an anonymous user

You may wish to define permissions for when there is no logged in current user (when `conn.assigns.current_user` is `nil`).
In this case, you should implement `Canada.Can` for `nil` like so:

```elixir
defimpl Canada.Can, for: Atom do
  # When the user is not logged in, all they can do is read Posts
  def can?(nil, :show, %Post{}), do: true
  def can?(nil, _, _), do: false
end
```

### Specifing database field

You can tell Canary to search for a resource using a field other than the default `:id` by using the `:id_field` option. Note that the specified field must be able to uniquely identify any resource in the specified table.

For example, if you want to access your posts using a string field called `slug`, you can use

```elixir
plug :load_and_authorize_resource, model: Post, id_name: "slug", id_field: "slug"
```

to load and authorize the resource `Post` with the slug specified by `conn.params["slug"]` value.

If you are using Phoenix, your `web/router.ex` should contain something like:

```elixir
resources "/posts", PostController, param: "slug"
```

Then your URLs will look like:

```
/posts/my-new-post
```

instead of

```
/posts/1
```

### Handling unauthorized actions

By default, when an action is unauthorized, Canary simply sets `conn.assigns.authorized` to `false`.
However, you can configure a handler function to be called when authorization fails. Canary will pass the `Plug.Conn` to the given function. The handler should accept a `Plug.Conn` as its only argument, and should return a `Plug.Conn`.

For example, to have Canary call `Helpers.handle_unauthorized/1`:

```elixir
config :canary, unauthorized_handler: {Helpers, :handle_unauthorized}
```

### Handling resource not found

By default, when a resource is not found, Canary simply sets the resource in `conn.assigns` to `nil`. Like unauthorized action handling , you can configure a function to which Canary will pass the `conn` when a resource is not found:

```elixir
config :canary, not_found_handler: {Helpers, :handle_not_found}
```

You can also specify handlers on an individual basis (which will override the corresponding configured handler, if any) by specifying the corresponding `opt` in the plug call:

```elixir
plug :load_and_authorize_resource Post,
  unauthorized_handler: {Helpers, :handle_unauthorized},
  not_found_handler: {Helpers, :handle_not_found}
```

Tip: If you would like the request handling to stop after the handler function exits, e.g. when redirecting, be sure to call `Plug.Conn.halt/1` within your handler like so:

```elixir
def handle_unauthorized(conn) do
  conn
  |> put_flash(:error, "You can't access that page!")
  |> redirect(to: "/")
  |> halt
end
```

Note: If both an `:unauthorized_handler` and a `:not_found_handler` are specified for `load_and_authorize_resource`, and the request meets the criteria for both, the `:unauthorized_handler` will be called first.

## License
MIT License. Copyright 2016 Chris Kelly.
