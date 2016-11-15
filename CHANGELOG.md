## Changelog

## v1.1.0
  * Enhancements
    * Add `non_id_actions` opt

## v1.0
  * Bug fixes
    * Do not clobber resources in the `Conn` on index action if they are of the same model

## v0.14.2
  * Relax Ecto version requirements

## v0.14.1
  * Bug fixes
    * Use Macro.underscore/1 instead of Mix.Utils.underscore/1 to avoid :mix dependency on production

## v0.14.0
  * Enhancements
    * You can now tell Canary to search for a resource using a field other than the default `:id` by using the `:id_field` option. Note that the specified field must be able to uniquely identify any resource in the specified table.
  * Dependency changes
    * Elixir ~> 1.2 is now required
    * Ecto ~> 1.1 is now required

## v0.13.1

  * Enhancements
    * If both an `:unauthorized_handler` and a `:not_found_handler` are specified for `load_and_authorize_resource`, and the request meets the criteria for both, the `:unauthorized_handler` will be called first.
  * Bug Fixes
    * If more than one handler are specified and the first handler halts the request, the second handler will be skipped.

## v0.13.0

  * Enhancements
    * Canary can now be configured to call a user-defined function when a resource is not found. The function is specified and used in a similar manner to `:unauthorized_handler`.
  * Bug Fixes
    * Disabled protocol consolidation in order for tests to work on Elixir 1.2

## v0.12.2

  * Deprecations
    * Canary now looks for the current action in `conn.assigns.canary_action` rather than `conn.assigns.action` in order to avoid conflicts. The `action` key is deprecated.

## v0.12.0

* Enhancements
  * Canary can now be configured to call a user-defined function when authorization fails. Canary will pass the `Plug.Conn` for the request to the given function. The handler should accept a `Plug.Conn` as its only argument, and should return a `Plug.Conn`.
    * For example, to have Canary call `Helpers.handle_unauthorized/1`:
    ```elixir
    config :canary, unauthorized_handler: {Helpers, :handle_unauthorized}
    ```
    * You can also specify the `:unauthorized_handler` on an individual basis by specifying the `:unauthorized_handler`   `opt` in the plug call like so:
    ```elixir
    plug :load_and_authorize_resource Post, unauthorized_handler: {Helpers, :handle_unauthorized}
    ```

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
  * Canary now favours looking for the current action in `conn.assigns.canary_action` rather than `conn.assigns.action` in order to avoid conflicts. The `action` key is deprecated

* Enhancements
  * The name of the id in `conn.params` can now be specified with the `id_name` opt
