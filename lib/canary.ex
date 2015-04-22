defmodule Canary do

  import Canada, only: [can?: 2]
  import Canada.Can, only: [can?: 3]

  @doc """
  Load the resource given by conn.params["id"] and ecto model given by
  opts[:model] into conn.assigns.loaded_resource.
  If the resource cannot be fetched, conn.assigns.load_resource is set
  to nil.
  """
  def load_resource(conn, opts) do
    loaded_resource = fetch_resource(
                        opts[:repo],
                        opts[:model],
                        conn.params["id"])

    %{ conn | assigns: Map.put(conn.assigns, :loaded_resource, loaded_resource) }
  end

  @doc """
  Authorize the current user for the given resource.
  In order to use this function,
    1) conn.assigns.current_user must be the module name of an ecto model, and
    2) conn.private must be a map.

  If authorization, succeeds, assign conn.assigns.authorized to true.
  If authorization, fails, assign conn.assigns.authorized to false.
  """
  def authorize_resource(conn = %{assigns: %{current_user: user}}, _opts) when is_nil(user) do
    %{ conn | assigns: Map.put(conn.assigns, :access_denied, true) }
  end

  def authorize_resource(conn, opts) do
    current_user = conn.assigns.current_user
    action = action(conn)
    resource = fetch_resource(opts[:repo], opts[:model], conn.params["id"])

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
  """
  def load_and_authorize_resource(conn, opts) do
    conn
    |> authorize_resource(opts)
    |> load_if_authorized(opts)
  end

  defp fetch_resource(repo, model, resource_id) do
    repo.get(model, resource_id)
  end

  defp action(conn) do
    conn.private
    |> Map.fetch(:phoenix_action)
    |> case do
      {:ok, action} -> action
      _             -> conn.assigns.action
    end
  end

  defp load_if_authorized(conn = %{assigns: %{authorized: true} }, opts), do: load_resource(conn, opts)
  defp load_if_authorized(conn = %{assigns: %{authorized: false} }, _opts), do: conn
end
