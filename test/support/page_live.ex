defmodule Canary.HooksHelper.PageLive do
  use Phoenix.LiveView
  use Canary.Hooks

  mount_canary :load_resource,
    model: Post,
    required: false

  mount_canary :load_and_authorize_resource,
    on: [:handle_params, :handle_event],
    model: User,
    only: [:show],
    required: false

  def render(assigns) do
    ~H"""
    <div>Page</div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  ## test helpers

  def handle_call({:run, func}, _, socket), do: func.(socket)

  def run(lv, func) do
    GenServer.call(lv.pid, {:run, func})
  end

  def fetch_lifecycle(lv) do
    run(lv, fn socket ->
      {:reply, Map.fetch(socket.private, :lifecycle), socket}
    end)
  end
end
