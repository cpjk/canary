defmodule Canary.Plugs do
  import Canada.Can, only: [can?: 3]
  import Ecto.Query

  @doc """
  Load the resource given by conn.params["id"] and ecto model given by
  opts[:model] into conn.assigns.loaded_resource.
  If the resource cannot be fetched, conn.assigns.load_resource is set
  to nil.

  If the action is "index", all records from the specified model will be loaded.

  """
  def load_resource(conn, opts) do
    loaded_resource = case get_action(conn) do
      :index ->
        fetch_all(opts[:model])
      _      ->
        fetch_resource(opts[:model], conn.params["id"])
    end

    %{ conn | assigns: Map.put(conn.assigns, :loaded_resource, loaded_resource) }
  end

  @doc """
  Authorize the current user for the given resource.
  In order to use this function,
    1) conn.assigns.current_user must be the module name of an ecto model, and
    2) conn.private must be a map.

  If authorization succeeds, assign conn.assigns.authorized to true.
  If authorization fails, assign conn.assigns.authorized to false.

  For the index action, the resource in the Canada.Can implementation
  should be the module name of the model rather than a struct.

  For example:
    use         def can?(%User{}, :index, Post), do: true
    instead of  def can?(%User{}, :index, %Post{}), do: true
  """
  def authorize_resource(conn = %{assigns: %{current_user: user}}, _opts) when is_nil(user) do
    %{ conn | assigns: Map.put(conn.assigns, :access_denied, true) }
  end

  def authorize_resource(conn, opts) do
    current_user = conn.assigns.current_user
    action = get_action(conn)

    resource = case action do
      :index ->
        opts[:model]
      _      ->
        fetch_resource(opts[:model], conn.params["id"])
    end

    case current_user |> can? action, resource do
      true ->
        %{ conn | assigns: Map.put(conn.assigns, :authorized, true) }
      false ->
        %{ conn | assigns: Map.put(conn.assigns, :authorized, false) }
    end
  end

  @doc """
  Authorize the given resource and then load it if
  authorization succeeds.

  If the resource cannot be loaded or authorization
  fails, conn.assigns.loaded_resource is set to nil.

  The result of the authorization (true/false) is
  assigned to conn.assigns.authorized.

  Also, see the documentation for load_resource/2 and
  authorize_resource/2.
  """
  def load_and_authorize_resource(conn, opts) do
    conn
    |> authorize_resource(opts)
    |> load_if_authorized(opts)
  end

  defp fetch_resource(model, resource_id) do
    Application.get_env(:canary, :repo).get(model, resource_id)
  end

  defp fetch_all(model) do
     from(m in model)
     |> select([m], m)
     |> Application.get_env(:canary, :repo).all
  end

  defp get_action(conn) do
    conn.assigns
    |> Map.fetch(:action)
    |> case do
      {:ok, action} -> action
      _             -> conn.private.phoenix_action
    end
  end

  defp load_if_authorized(conn = %{assigns: %{authorized: true} }, opts), do: load_resource(conn, opts)
  defp load_if_authorized(conn = %{assigns: %{authorized: false} }, _opts) do
    %{ conn | assigns: Map.put(conn.assigns, :loaded_resource, nil) }
  end
end
