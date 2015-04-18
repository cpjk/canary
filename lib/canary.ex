defmodule Canary do

  @doc """
  Load the resource given by conn.params["id"] and
  add it to conn.assigns.
  """
  def load_resource(conn, opts) do
    fetched_resource = opts[:resource]
    |> fetch_resource(conn.params["id"])

    %{ conn | assigns: Map.put(conn.assigns, :fetched_resource, fetched_resource) }
  end

  @doc """
  Fetch the resource from the database. Initially only supports ecto.
  Need a place to define which repo to use
  """
  defp fetch_resource(resource, resource_id) do
    Cooking.Repo.get(resource, resource_id)
  end
end
