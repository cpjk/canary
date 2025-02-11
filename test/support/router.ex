defmodule Canary.HooksHelper.Router do
  use Phoenix.Router
  import Plug.Conn
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :fetch_session
    plug :accepts, ["html"]
    plug :fetch_live_flash
  end

  scope "/" do
    pipe_through :browser

    live "/page", Canary.HooksHelper.PageLive
    live "/post", Canary.HooksHelper.PostLive
    live "/post/:id", Canary.HooksHelper.PostLive, :show
    live "/post/:id/edit", Canary.HooksHelper.PostLive, :edit
    live "/post/:id/update", Canary.HooksHelper.PostLive, :update
  end
end
