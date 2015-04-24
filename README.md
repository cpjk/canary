Canary
======

An authorization library for Elixir applications that restricts what resources
the current user is allowed to access.

Inspired by [CanCan](https://github.com/CanCanCommunity/cancancan) for Ruby on Rails.

## Installation ##
In your ```mix.exs``` file:
```elixir
defp deps do
  {:canary, "~> 0.1.0"}
end
```

Then run ```mix deps.get``` to fetch the dependencies.

## Usage ##

Canary provides three functions to be used as plugs to load and authorize resources:

```load_resource/2```, ```authorize_resource/2```, and ```load_and_authorize_resource/2```.

All three functions require ```conn.assigns.current_user``` to contain an Ecto record holding the current_user.

Just ```use Canary``` in order to use the plugs. In a Phoenix app the best place would probably be in your ```web/web.ex```.

####load_resource/2####
Loads the resource with the id in ```conn.params["id"]``` from the database using the given Ecto repo and model, and assigns the resource to ```conn.assigns.fetched_resource```.

For example,

```elixir
plug :load_resource, model: Project.User, repo: Project.Repo
```
Will load the ```Project.User``` with id given in the ```conn.params["id"]``` through ```Project.Repo```.

####authorize_resource/2####
Checks whether or not the ```current_user``` can perform the given action on the given resource and assigns the result (true/false) to ```conn.assigns.authorized```. It is up to you to decide what to do with the result.

For Phoenix applications, Canary determines the action automatically.

For non-Phoenix applications, you simply ensure that ```conn.assigns.action``` contains an atom specifying the action.

In order to authorize resources, you must specify permissions by implementing the [Canada.Can protocol](https://github.com/jarednorman/canada) for your ```User``` model (Canada is included as a light weight dependency).

####load_and_authorize_resource/2####
Authorizes the resource and then loads it if authorization succeeds. Again, the resource is loaded into ```conn.assigns.fetched_resource```.

In the following example, the ```User``` with the same id as the ```current_user``` is be loaded if authorization succeeds.

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

To automatically load the  ```Project.User``` with the ```id``` given in the params, you would plug your ```UserController``` like so:

```elixir
plug :load_and_authorize_resource, model: Project.User, repo: Project.Repo
```

In this case, the ```Project.User``` specified by ```conn.params["id]``` is loaded into ```conn.assigns.fetched_resource``` for ```GET /users/12```, but _not_ for ```DELETE /users/12```.

In this case, on ```GET /users/12``` authorization succeeds, and the ```Project.User``` specified by ```conn.params["id]``` will be loaded into ```conn.assigns.fetched_resource```.

However, on ```DELETE /users/12```, authorization fails and the resource is not loaded. 
