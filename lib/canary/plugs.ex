defmodule Canary.Plugs do
  import Canada.Can, only: [can?: 3]
  import Ecto.Query
  import Keyword, only: [has_key?: 2]

  @moduledoc """
  Plug functions for loading and authorizing resources for the current request.

  The plugs all store data in conn.assigns (in Phoenix applications, keys in conn.assigns can be accessed with `@key_name` in templates)

  In order to use the plug functions, you must `use Canary`.

  You must also specify the Ecto repo to use in your configuration:
  ```
  config :canary, repo: Project.Repo
  ```
  If you wish, you may also specify the key where Canary will look for the current user record to authorize against:
  ```
  config :canary, current_user: :some_current_user
  ```

  You can specify a handler function (in this case, `Helpers.handle_unauthorized`) to be called when an action is unauthorized like so:
  ```elixir
  config :canary, unauthorized_handler: {Helpers, :handle_unauthorized}
  ```
  or to handle when a resource is not found:
  ```elixir
  config :canary, not_found_handler: {Helpers, :handle_not_found}
  ```
  Canary will pass the `conn` to the handler function.
  """

  @doc """
  Load the given resource.

  Load the resource with id given by `conn.params["id"]` (or `conn.params[opts[:id_name]]` if `opts[:id_name]` is specified)
  and ecto model given by `opts[:model]` into `conn.assigns.resource_name`.

  `resource_name` is either inferred from the model name or specified in the plug declaration with the `:as` key.
  To infer the `resource_name`, the most specific(right most) name in the model's
  module name will be used, converted to underscore case.

  For example, `load_resource model: Some.Project.BlogPost` will load the resource into
  `conn.assigns.blog_post`

  If the resource cannot be fetched, `conn.assigns.resource_name` is set
  to nil.

  By default, when the action is `:index`, all records from the specified model will be loaded. This can
  be overridden to fetch a single record from the database by using the `:persisted` key.

  Currently, `:new` and `:create` actions are ignored, and `conn.assigns.resource_name`
  will be set to nil for these actions. This can be overridden to fetch a single record from the database
  by using the `:persisted` key.

  The `:persisted` key can override how a resource is loaded and can be useful when dealing
  with nested resources.

  Required opts:

  * `:model` - Specifies the module name of the model to load resources from

  Optional opts:

  * `:as` - Specifies the `resource_name` to use
  * `:only` - Specifies which actions to authorize
  * `:except` - Specifies which actions for which to skip authorization
  * `:preload` - Specifies association(s) to preload
  * `:id_name` - Specifies the name of the id in `conn.params`, defaults to "id"
  * `:persisted` - Specifies the resource should always be loaded from the database, defaults to false
  * `:not_found_handler` - Specify a handler function to be called if the resource is not found

  Examples:
  ```
  plug :load_resource, model: Post

  plug :load_resource, model: User, preload: :posts, as: :the_user

  plug :load_resource, model: User, only: [:index, :show], preload: :posts, as: :person

  plug :load_resource, model: User, except: [:destroy]

  plug :load_resource, model: Post, id_name: "post_id", only: [:new, :create], persisted: true
  ```
  """
  def load_resource(conn, opts) do
    conn
    |> action_valid?(opts)
    |> case do
      true  -> _load_resource(conn, opts) |> handle_not_found(opts)
      false -> conn
    end
  end

  defp _load_resource(conn, opts) do
    action = get_action(conn)
    is_persisted = persisted?(opts)

    loaded_resource = cond do
      is_persisted ->
        fetch_resource(conn, opts)
      action == :index ->
        fetch_all(conn, opts)
      action in [:new, :create] ->
        nil
      true ->
        fetch_resource(conn, opts)
    end

    %{conn | assigns: Map.put(conn.assigns, resource_name(conn, opts), loaded_resource)}
  end

  @doc """
  Authorize the current user for the given resource.

  In order to use this function,

    1) `conn.assigns[Application.get_env(:canary, :current_user, :current_user)]` must be an ecto
    struct representing the current user

    2) `conn.private` must be a map (this should not be a problem unless you explicitly modified it)

  If authorization succeeds, sets `conn.assigns.authorized` to true.

  If authorization fails, sets `conn.assigns.authorized` to false.

  For the `:index`, `:new`, and `:create` actions, the resource in the `Canada.Can` implementation
  should be the module name of the model rather than a struct. A struct should be used instead of
  the module name only if the `:persisted` key is used and you want to override the default
  authorization behavior.  This can be useful when dealing with nested resources.

  For example:

    use
    ```
    def can?(%User{}, :index, Post), do: true
    ```
    instead of
    ```
    def can?(%User{}, :index, %Post{}), do: true
    ```

    or

    use
    ```
    def can?(%User{id: user_id}, :index, %Post{user_id: user_id}), do: true
    ```

    if you are dealing with a nested resource, such as, "/post/post_id/comments"

  Required opts:

  * `:model` - Specifies the module name of the model to authorize access to

  Optional opts:

  * `:only` - Specifies which actions to authorize
  * `:except` - Specifies which actions for which to skip authorization
  * `:preload` - Specifies association(s) to preload
  * `:id_name` - Specifies the name of the id in `conn.params`, defaults to "id"
  * `:persisted` - Specifies the resource should always be loaded from the database, defaults to false
  * `:unauthorized_handler` - Specify a handler function to be called if the action is unauthorized

  Examples:
  ```
  plug :authorize_resource, model: Post

  plug :authorize_resource, model: User, preload: :posts

  plug :authorize_resource, model: User, only: [:index, :show], preload: :posts

  plug :load_resource, model: Post, id_name: "post_id", only: [:index], persisted: true, preload: :comments
  ```
  """
  def authorize_resource(conn, opts) do
    conn
    |> action_valid?(opts)
    |> case do
      true  -> _authorize_resource(conn, opts) |> handle_unauthorized(opts)
      false -> conn
    end
  end

  defp _authorize_resource(conn, opts) do
    current_user_name = opts[:current_user] || Application.get_env(:canary, :current_user, :current_user)
    current_user = Dict.fetch! conn.assigns, current_user_name
    action = get_action(conn)
    is_persisted = persisted?(opts)

    resource = cond do
      is_persisted ->
        fetch_resource(conn, opts)
      action in [:index, :new, :create] ->
        opts[:model]
      true ->
        fetch_resource(conn, opts)
    end

    case current_user |> can? action, resource do
      true  ->
        %{conn | assigns: Map.put(conn.assigns, :authorized, true)}
      false ->
        %{conn | assigns: Map.put(conn.assigns, :authorized, false)}
    end
  end

  @doc """
  Authorize the given resource and then load it if
  authorization succeeds.

  If the resource cannot be loaded or authorization
  fails, conn.assigns.resource_name is set to nil.

  The result of the authorization (true/false) is
  assigned to conn.assigns.authorized.

  Also, see the documentation for load_resource/2 and
  authorize_resource/2.

  Required opts:

  * `:model` - Specifies the module name of the model to load resources from

  Optional opts:

  * `:as` - Specifies the `resource_name` to use
  * `:only` - Specifies which actions to authorize
  * `:except` - Specifies which actions for which to skip authorization
  * `:preload` - Specifies association(s) to preload
  * `:id_name` - Specifies the name of the id in `conn.params`, defaults to "id"
  * `:unauthorized_handler` - Specify a handler function to be called if the action is unauthorized
  * `:not_found_handler` - Specify a handler function to be called if the resource is not found

  Examples:
  ```
  plug :load_and_authorize_resource, model: Post

  plug :load_and_authorize_resource, model: User, preload: :posts, as: :the_user

  plug :load_and_authorize_resource, model: User, only: [:index, :show], preload: :posts, as: :person

  plug :load_and_authorize_resource, model: User, except: [:destroy]
  ```
  """
  def load_and_authorize_resource(conn, opts) do
    conn
    |> action_valid?(opts)
    |> case do
      true  -> _load_and_authorize_resource(conn, opts)
      false -> conn
    end
  end

  defp _load_and_authorize_resource(conn, opts) do
    conn
    |> Map.put(:skip_canary_handler, true) # skip not_found_handler so auth handler can catch first if needed
    |> load_resource(opts)
    |> Map.delete(:skip_canary_handler) # allow auth handling
    |> authorize_resource(opts)
    |> maybe_handle_not_found(opts)
    |> purge_resource_if_unauthorized(opts)
  end

  # Only try to handle 404 if the response has not been sent during authorization handling
  defp maybe_handle_not_found(conn = %{state: :sent}, opts), do: conn
  defp maybe_handle_not_found(conn, opts), do: handle_not_found(conn, opts)

  defp purge_resource_if_unauthorized(conn = %{assigns: %{authorized: true}}, _opts),
    do: conn
  defp purge_resource_if_unauthorized(conn = %{assigns: %{authorized: false}}, opts),
    do: %{conn | assigns: Map.put(conn.assigns, resource_name(conn, opts), nil)}

  defp fetch_resource(conn, opts) do
    repo = Application.get_env(:canary, :repo)

    id = get_resource_id(conn, opts)

    conn.assigns
    |> Map.fetch(resource_name(conn, opts)) # check if a resource is already loaded at the key
    |> case do
      :error ->
        repo.get(opts[:model], id)
        |> preload_if_needed(repo, opts)
      {:ok, nil} ->
        repo.get(opts[:model], id)
        |> preload_if_needed(repo, opts)
      {:ok, resource} ->
        case (resource.__struct__ == opts[:model]) do
          true  -> # A resource of the type passed as opts[:model] is already loaded; do not clobber it
            resource
          false ->
            repo.get(opts[:model], id)
            |> preload_if_needed(repo, opts)
        end
    end
  end

  defp fetch_all(conn, opts) do
    repo = Application.get_env(:canary, :repo)

    conn
    |> Map.fetch(resource_name(conn, opts))
    |> case do # check if a resource is already loaded at the key
      :error ->
        from(m in opts[:model]) |> select([m], m) |> repo.all |> preload_if_needed(repo, opts)
      {:ok, resource} ->
        case (resource.__struct__ == opts[:model]) do
          true  ->
            resource
          false ->
            from(m in opts[:model]) |> select([m], m) |> repo.all |> preload_if_needed(repo, opts)
        end
    end
  end

  defp get_resource_id(conn, opts) do
    case opts[:id_name] do
      nil ->
        conn.params["id"]
      id_name ->
        conn.params[id_name]
    end
  end

  defp get_action(conn) do
    conn.assigns
    |> Map.fetch(:canary_action)
    |> case do
      {:ok, action} -> action
      _             -> conn.private.phoenix_action
    end
  end

  defp action_exempt?(conn, opts) do
    action = get_action(conn)

    (is_list(opts[:except]) && action in opts[:except])
    |> case do
      true  -> true
      false -> action == opts[:except]
    end
  end

  defp action_included?(conn, opts) do
    action = get_action(conn)

    (is_list(opts[:only]) && action in opts[:only])
    |> case do
      true  -> true
      false -> action == opts[:only]
    end
  end

  defp action_valid?(conn, opts) do
    cond do
      has_key?(opts, :except) && has_key?(opts, :only) ->
        false
      has_key?(opts, :except) ->
        !action_exempt?(conn, opts)
      has_key?(opts, :only) ->
        action_included?(conn, opts)
      true ->
        true
    end
  end

  defp persisted?(opts) do
    !!Keyword.get(opts, :persisted, false)
  end

  defp resource_name(conn, opts) do
    case opts[:as] do
      nil ->
        opts[:model]
        |> Module.split
        |> List.last
        |> Mix.Utils.underscore
        |> pluralize_if_needed(conn, opts)
        |> String.to_atom
      as -> as
    end
  end

  defp pluralize_if_needed(name, conn, opts) do
    if get_action(conn) in [:index] and not persisted?(opts) do
      name <> "s"
    else
      name
    end
  end

  defp preload_if_needed(nil, _repo, _opts) do
    nil
  end

  defp preload_if_needed(records, repo, opts) do
    case opts[:preload] do
      nil ->
        records
      models ->
        repo.preload(records, models)
    end
  end

  defp handle_unauthorized(conn = %{skip_canary_handler: true}, opts),
    do: conn
  defp handle_unauthorized(conn = %{assigns: %{authorized: true}}, _opts),
    do: conn
  defp handle_unauthorized(conn = %{assigns: %{authorized: false}}, opts),
    do: apply_error_handler(conn, :unauthorized_handler, opts)

  defp handle_not_found(conn = %{skip_canary_handler: true}, opts) do
    conn
  end

  defp handle_not_found(conn, opts) do
    action = get_action(conn)

    case is_nil(Map.get(conn.assigns, resource_name(conn, opts)))
      and not action in [:index, :new, :create] do

      true -> apply_error_handler(conn, :not_found_handler, opts)
      false -> conn
    end
  end

  defp apply_error_handler(conn, handler_key, opts) do
    handler = Keyword.get(opts, handler_key)
      || Application.get_env(:canary, handler_key)

    case handler do
      {mod, fun} -> apply(mod, fun, [conn])
      nil        -> conn
    end
  end
end
