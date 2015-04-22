defmodule Canary do
  alias Cooking.Repo

  import Canada, only: [can?: 2]
  import Canada.Can, only: [can?: 3]

  @doc """
  Load the resource given by conn.params["id"] and ecto model given by
  opts[:model] into conn.assigns.loaded_resource.
  """
  def load_resource(conn, opts) do
    loaded_resource = opts[:model]
    |> fetch_resource(conn.params["id"])

    %{ conn | assigns: Map.put(conn.assigns, :loaded_resource, loaded_resource) }
  end


  @doc """
  Fetch the resource from the database.
  TODO Need a place to define which repo to use.
  """
  defp fetch_resource(model, resource_id) do
    Repo.get(model, resource_id)
  end

  @doc """
  Authorizes the current user for the given resource.
  In order for authorization, conn.assigns.current_users
  must contain an ecto model.
  Throws an exceptionggj
  """
  def authorize_resource(conn = %{assigns: %{current_user: user}}, _opts) when is_nil(user) do
    %{ conn | assigns: Map.put(conn.assigns, :access_denied, true) }
  end

  def authorize_resource(conn, opts) do
    current_user = conn.assigns.current_user
    model = opts[:model]
    resource = Repo.get(model, conn.params["id"])
    action = conn.private.phoenix_action

    case current_user |> can? action, resource do
      true ->
        %{ conn | assigns: Map.put(conn.assigns, :authorized, true) }
      false ->
        %{ conn | assigns: Map.put(conn.assigns, :authorized, false) }
    end
  end

  def load_and_authorize_resource(conn, opts) do
    conn
    |> authorize_resource(opts)
    |> load_if_authorized(opts)
  end

  defp load_if_authorized(conn = %{assigns: %{authorized: true} }, opts), do: load_resource(conn, opts)
  defp load_if_authorized(conn = %{assigns: %{authorized: false} }, _opts), do: conn
end
