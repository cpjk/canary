Canary
======
[![Build Status](https://travis-ci.org/cpjk/canary.svg?branch=master)](https://travis-ci.org/cpjk/canary)
[![Hex pm](https://img.shields.io/hexpm/v/canary.svg?style=flat)](https://hex.pm/packages/canary)

An authorization library in Elixir for Plug applications that restricts what resources
the current user is allowed to access, and automatically loads resources for the current request.

Inspired by [CanCan](https://github.com/CanCanCommunity/cancancan) for Ruby on Rails.

[Read the docs](http://hexdocs.pm/canary)

## Installation

For the latest master:

```elixir
defp deps do
  {:canary, github: "cpjk/canary"}
end
```

For the latest release:

```elixir
defp deps do
  {:canary, "~> 1.1.1"}
end
```

Then run `mix deps.get` to fetch the dependencies.

## Usage

Canary provides three functions to be used as plugs to load and authorize resources:

`load_resource/2`, `authorize_resource/2`, and `load_and_authorize_resource/2`.

`load_resource/2` and `authorize_resource/2` can be used by themselves, while `load_and_authorize_resource/2` combines them both.

In order to use Canary, you will need, at minimum:

- A [Canada.Can protocol](https://github.com/jarednorman/canada) implementation (a good place would be `lib/abilities.ex`)

- An Ecto record struct containing the user to authorize in `conn.assigns.current_user` (the key can be customized - see https://github.com/cpjk/canary#overriding-the-default-user).

- Your Ecto repo specified in your `config/config.exs`: `config :canary, repo: YourApp.Repo`

Then, just `import Canary.Plugs` in order to use the plugs. In a Phoenix app the best place would probably be inside `controller/0` in your `web/web.ex`, in order to make the functions available in all of your controllers.

### load_resource/2

Loads the resource having the id given in `conn.params["id"]` from the database using the given Ecto repo and model, and assigns the resource to `conn.assigns.<resource_name>`, where `resource_name` is inferred from the model name.

For example,

```elixir
plug :load_resource, model: Project.Post
```
Will load the `Project.Post` having the id given in `conn.params["id"]` through `YourApp.Repo`, into
`conn.assigns.post`

### authorize_resource/2

Checks whether or not the `current_user` for the request can perform the given action on the given resource and assigns the result (true/false) to `conn.assigns.authorized`. It is up to you to decide what to do with the result.

For Phoenix applications, Canary determines the action automatically.

For non-Phoenix applications, or to override the action provided by Phoenix, simply ensure that `conn.assigns.canary_action` contains an atom specifying the action.

In order to authorize resources, you must specify permissions by implementing the [Canada.Can protocol](https://github.com/jarednorman/canada) for your `User` model (Canada is included as a light weight dependency).

### load_and_authorize_resource/2

Authorizes the resource and then loads it if authorization succeeds. Again, the resource is loaded into `conn.assigns.<resource_name>`.

In the following example, the `Post` with the same `user_id` as the `current_user` is only loaded if authorization succeeds.

### Usage Example

Let's say you have a Phoenix application with a `Post` model, and you want to authorize the `current_user` for accessing `Post` resources.

Let's suppose that you have a file named `lib/abilities.ex` that contains your Canada authorization rules like so:

```elixir
defimpl Canada.Can, for: User do
  def can?(%User{ id: user_id }, action, %Post{ user_id: user_id })
    when action in [:show], do: true

  def can?(%User{ id: user_id }, _, _), do: false
end
```
and in your `web/router.ex:` you have:

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

### Excluding actions

To exclude an action from any of the plugs, pass the `:except` key, with a single action or list of actions.

For example,

Single action form:

```elixir
plug :load_and_authorize_resource, model: Post, except: :show
```

List form:

```elixir
plug :load_and_authorize_resource, model: Post, except: [:show, :create]
```

### Authorizing only specific actions

To specify that a plug should be run only for a specific list of actions, pass the `:only` key, with a single action or list of actions.

For example,

Single action form:

```elixir
plug :load_and_authorize_resource, model: Post, only: :show
```

List form:

```elixir
plug :load_and_authorize_resource, model: Post, only: [:show, :create]
```

Note: Passing both `:only` and `:except` to a plug is invalid. Canary will simply pass the `Conn` along unchanged.

### Overriding the default user

Globally, the default key for finding the user to authorize can be set in your configuration as follows:

```elixir
config :canary, current_user: :some_current_user
```

In this case, canary will look for the current user record in `conn.assigns.some_current_user`.

The current user key can also be overridden for individual plugs as follows:

```elixir
plug :load_and_authorize_resource, model: Post, current_user: :current_admin
```

### Specifying resource_name

To specify the name under which the loaded resource is stored, pass the `:as` flag in the plug declaration.

For example,

```elixir
plug :load_and_authorize_resource, model: Post, as: :new_post
```

will load the post into `conn.assigns.new_post`

### Preloading associations

Associations can be preloaded with `Repo.preload` by passing the `:preload` option with the name of the association:

```elixir
plug :load_and_authorize_resource, model: Post, preload: :comments
```

### Non-id actions

For the `:index`, `:new`, and `:create` actions, the resource passed to the `Canada.Can` implementation
should be the *module* name of the model rather than a struct.

For example, when authorizing access to the `Post` resource,

you should use

```elixir
def can?(%User{}, :index, Post), do: true
```

instead of

```elixir
def can?(%User{}, :index, %Post{}), do: true
```

You can specify additional actions for which Canary will authorize based on the model name, by passing the `non_id_actions` opt to the plug.

For example,
```elixir
plug :authorize_resource, model: Post, non_id_actions: [:find_by_name]
```

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

### Nested associations

Sometimes you need to load and authorize a parent resource when you have a relationship between two resources and you are
creating a new one or listing all the children of that parent.  By specifying the `:persisted` option with `true`
you can load and/or authorize a nested resource.  Specifying this option overrides the default loading behavior of the
`:index`, `:new`, and `:create` actions by loading an individual resource.  It also overrides the default
authorization behavior of the `:index`, `:new`, and `create` actions by loading a struct instead of a module
name for the call to `Canada.can?`.

For example, when loading and authorizing a `Post` resource which can have one or more `Comment` resources, use

```elixir
plug :load_and_authorize_resource, model: Post, id_name: "post_id", persisted: true, only: [:create]
```

to load and authorize the parent `Post` resource using the `post_id` in /posts/:post_id/comments before you
create the `Comment` resource using its parent.

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

You can also specify handlers on an an individual basis (which will override the corresponding configured handler, if any) by specifying the corresponding `opt` in the plug call:

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
