defmodule Canary.LoadResource do

  def init(options) do
    options
  end

  def call(conn, opts) do
    conn
    |> load_resource(opts[:resource])
  end

  @doc """
  Load the resource given by conn.params["id"] and
  add it to conn.assigns.
  """
  def load_resource(conn, resource) do
    fetched_resource = resource
    |> fetch_resource(conn.params["id"])

    %{ conn | assigns: Map.put(conn.assigns, :fetched_resource, fetched_resource) }
  end

  @doc """
  Fetch the resource from the database. Initially only supports ecto.
  Need a place to define which repo to use
  """
  def fetch_resource(resource, resource_id) do
    Cooking.Repo.get(resource, resource_id)
  end
end
