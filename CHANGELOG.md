## Changelog

## v0.11.0

* Enhancements
  * Resources can now be loaded on `:new` and `:create` actions, when `persisted: true` is specified in the plug call. This allows parent resources to be loaded when a child is created. For example, if a `Post` resource has multiple `Comment` children, you may want to load the parent `Post` when creating a new `Comment`. You can load the parent `Post` with a separate
  ```elixir
  plug :load_and_authorize_resource, model: Post, id_name: "post_id", persisted: true, only: [:create]
  ```
  This will cause Canary to try to load the corresponding `Post` from the database when creating a `Comment` at the URL `/posts/:post_id/comments`

## v0.10.0

* Bug fix
  * Correctly checks `conn.assigns` for pre-existing resource

* Deprecations
  * Canary will now favours looking for the current action in `conn.assigns.canary_action` rather than `conn.assigns.action` in order to avoid conflicts. The `canary_action` key is deprecated

* Enhancements
  * The name of the id in `conn.params` can now be specified with the `id_name` opt
