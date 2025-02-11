defmodule Canary do
  @moduledoc """
  An authorization library in Elixir for `Plug` and `Phoenix.LiveView` applications that restricts what resources the current user is allowed to access, and automatically load and assigns resources.

  `load_resource/2` and `authorize_resource/2` can be used by themselves, while `load_and_authorize_resource/2` combines them both.

  The plug functions are defined in `Canary.Plugs`

  In order to use `Canary` authorization in standard pages with plug, just `import Canary.Plugs` and use plugs, for example:

  ```elixir
  defmodule MyAppWeb.PostController do
    use MyAppWeb, :controller
    import Canary.Plugs

    plug :load_and_authorize_resource,
      model: Post,
      current_user: :current_user,
      only: [:show, :edit, :update]
  end
  ```

  The LiveView hooks are defined in `Canary.Hooks`

  In order to use `Canary` authorization in LiveView, just `use Canary.Hooks` and mount hooks, for example:

  ```elixir
  defmodule MyAppWeb.PostLive do
    use MyAppWeb, :live_view
    use Canary.Hooks

    mount_canary :load_and_authorize_resource,
      on: [:handle_params, :handle_event],
      current_user: :current_user,
      model: Post,
      only: [:show, :edit, :update]

  end
  ```

  This will attach hooks to the LiveView module with `Phoenix.LiveView.attach_hook/4`.
  In the example above hooks will be attached to `handle_params` and `handle_event` stages of the LiveView lifecycle.

  Please read the documentation for `Canary.Plugs` and `Canary.Hooks` for more information.
  """
end
