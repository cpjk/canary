Canary
======

An authorization library in Elixir for Plug applications that restricts what resources
the current user is allowed to access, and automatically loads resources for the current request.

Inspired by [CanCan](https://github.com/CanCanCommunity/cancancan) for Ruby on Rails.

[Read the docs](http://hexdocs.pm/canary)

## Installation ##
For the latest master:

```elixir
defp deps do
  {:canary, github: "cpjk/canary"}
end
```

For the latest release:

```elixir
defp deps do
  {:canary, "~> 0.9.1"}
end
```

Then run ```mix deps.get``` to fetch the dependencies.

## Usage ##

Canary provides three functions to be used as plugs to load and authorize resources:

```load_resource/2```, ```authorize_resource/2```, and ```load_and_authorize_resource/2```.

Just ```import Canary.Plugs``` in order to use the plugs. In a Phoenix app the best place would probably be in your ```web/web.ex```.

By default, Canary expects  ```conn.assigns.current_user``` to contain an Ecto record representing the user to authorize.

Specify your Ecto repo in your configuration:

```
config :canary, repo: Project.Repo
```

####load_resource/2####
Loads the resource having the id given in ```conn.params["id"]``` from the database using the given Ecto repo and model, and assigns the resource to ```conn.assigns.<resource_name>```, where `resource_name` is inferred from the model name.

For example,

```elixir
plug :load_resource, model: Project.User
```
Will load the ```Project.User``` having the id given in ```conn.params["id"]``` through ```Project.Repo```, into
`conn.assigns.user`

####authorize_resource/2####
Checks whether or not the ```current_user``` can perform the given action on the given resource and assigns the result (true/false) to ```conn.assigns.authorized```. It is up to you to decide what to do with the result.

For Phoenix applications, Canary determines the action automatically.

For non-Phoenix applications, or to override the action provided by Phoenix, simply ensure that ```conn.assigns.canary_action``` contains an atom specifying the action.

In order to authorize resources, you must specify permissions by implementing the [Canada.Can protocol](https://github.com/jarednorman/canada) for your ```User``` model (Canada is included as a light weight dependency).

####load_and_authorize_resource/2####
Authorizes the resource and then loads it if authorization succeeds. Again, the resource is loaded into ```conn.assigns.<resource_name>```.

In the following example, the ```User``` with the same id as the ```current_user``` is only loaded if authorization succeeds.

####Example####
Let's say you have a Phoenix application with a ```User``` model, and you want to authorize the ```current_user``` for accessing ```User``` resources.

Let's suppose that you have implemented Canada.Can in your ```abilities.ex``` like so:

```elixir
defimpl Canada.Can, for: User do
  def can?(%User{ id: user_id }, action, %User{ id: user_id })
    when action in [:show], do: true

  def can?(%User{ id: user_id }, _, _), do: false
end
```
and in your ```web/router.ex:``` you have:

```elixir
get "/users/:id", UserController, :show
delete "/users/:id", UserController, :delete
```

To automatically load and authorize the  ```Project.User``` having the ```id``` given in the params, you would plug your ```UserController``` like so:

```elixir
plug :load_and_authorize_resource, model: Project.User
```

In this case, the ```Project.User``` specified by ```conn.params["id]``` is loaded into ```conn.assigns.user``` for ```GET /users/12```, but _not_ for ```DELETE /users/12```.

In this case, on ```GET /users/12``` authorization succeeds, and the ```Project.User``` specified by ```conn.params["id]``` will be loaded into ```conn.assigns.user```.

However, on ```DELETE /users/12```, authorization fails and the resource is not loaded.

#### Excluding actions ####

To exclude an action from any of the plugs, pass the ```:except``` key, with a single action or list of actions.

For example,

Single action form:
```elixir
plug :load_and_authorize_resource, model: Project.User, except: :show
```
List form:
```elixir
plug :load_and_authorize_resource, model: Project.User, except: [:show, :create]
```

#### Authorizing only specific actions ####

To specify that a plug should be run only for a specific list of actions, pass the ```:only``` key, with a single action or list of actions.

For example,

Single action form:
```elixir
plug :load_and_authorize_resource, model: Project.User, only: :show
```
List form:
```elixir
plug :load_and_authorize_resource, model: Project.User, only: [:show, :create]
```

Note: Passing both ```:only``` and ```:except``` to a plug is invalid. Currently, the plug will simply pass the ```Conn``` along unchanged.

#### Overriding the default user

Globally, the default key for finding the user to authorize can be set in your configuration as follows:
```elixir
config :canary, current_user: :some_current_user
```
In this case, canary will look for the current user record in ```conn.assigns.some_current_user```.

The current user can also be overridden for individual plugs as follows:
```elixir
plug :load_and_authorize_resource, model: Project.User, current_user: :current_admin
```

#### Specifying resource_name

To specify the name under which the loaded resource is stored, pass the `:as` flag in the plug declaration.

For example,
```elixir
plug :load_and_authorize_resource, model: Project.Post, as: :new_post
```
will load the post into `conn.assigns.new_post`

#### Preloading associations

Associations can be preloaded with ```Repo.preload``` by passing the ```:preload``` option with the name of the association:

```elixir
plug :load_and_authorize_resource, model: Project.User, preload: :posts
```
#### A note about index, new, and create actions
For the `:index`, `:new`, and `:create` actions, the resource passed to the `Canada.Can` implementation
should be the *module* name of the model rather than a struct.

For example, when authorizing access to the `Post` resource,

  use

  ```
  def can?(%User{}, :index, Post), do: true
  ```

  instead of

  ```
  def can?(%User{}, :index, %Post{}), do: true
  ```
