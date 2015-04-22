Canary
======

An authorization library for Elixir applications that restricts what resources
the current user is allowed to access.

## Installation ##
In your ```mix.exs``` file:
```elixir
defp deps do
  {:canary, github: "cpjk/canary"}
end
```

Then run ```mix deps.get``` to fetch the dependencies.

## Usage ##

Canary provides three functions for that can be used as plugs to load and authorize resources:

```load_resource/2```, ```authorize_resource/2```, and ```load_and_authorize_resource/2```.

All three functions require ```conn.assigns.current_user``` to contain an Ecto record holding the current_user.

####load_resource/2####
Loads the resource with the id in ```conn.params["id"]``` from the database using the given Ecto repo and model, and assigns the resource to ```conn.assigns.fetched_resource```.

For example,

```elixir
plug :load_resource, model: Project.User, repo: Project.Repo
```
Will load the ```Project.User``` with id given in the ```conn.params["id"]``` through ```Project.Repo```.

####authorize_resource/2####
Authorizes that the current user can perform the given action on the given resource.

For Phoenix applications, the action is determined automatically from the connection.

For non-Phoenix applications, simply ensure that conn.assigns.action contains an atom specifying the action.

In order to authorize resources, you must implement the [Canada protocol](https://github.com/jarednorman/canada) for your ```User``` model.
