defmodule Canary.HooksHelper.PostLive do
  use Phoenix.LiveView
  use Canary.Hooks

  mount_canary :load_resource,
    model: Post,
    only: [:show]

  mount_canary :load_resource,
    model: Post,
    only: [:edit, :update]

  def render(assigns) do
    ~H"""
    <div>Post</div>
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

  def fetch_assigns(lv) do
    run(lv, fn socket ->
      {:reply, socket.assigns, socket}
    end)
  end

  def fetch_socket(lv) do
    run(lv, fn socket ->
      {:reply, socket, socket}
    end)
  end
end
