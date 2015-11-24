## Changelog

## v0.10.0

* Bug fix
  * Correctly checks `conn.assigns` for pre-existing resource

* Deprecations
  * Canary will now favours looking for the current action in `conn.assigns.canary_action` rather than `conn.assigns.action` in order to avoid conflicts. The `canary_action` key is deprecated

* Enhancements
  * The name of the id in `conn.params` can now be specified with the `id_name` opt
