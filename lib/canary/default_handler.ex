defmodule Canary.DefaultHandler do
  @moduledoc """
  The fallback Canary handler.

  This module is used primarily as a backwards compatibility for the `:not_found_handler` and `:unauthorized_handler`.
  It uses old configuration values to determine how to handle the error.

  If you are using `Canary` only with `Plug` based authorization then you can still
  use the `:not_found_handler` and `:unauthorized_handler` configuration values.
  Otherwise, you should implement the `Canary.ErrorHandler` behaviour in your own module.
  """
  @moduledoc since: "2.0.0"

  @behaviour Canary.ErrorHandler

  @doc """
  The default handler for when a resource is not found.
  For Plug based authorization it will use the global `:not_found_handler` or return the conn.

  For LiveView base authorization it will halt socket.
  """
  @impl true
  def not_found_handler(%Plug.Conn{} = conn) do
    case Application.get_env(:canary, :not_found_handler) do
      {mod, fun} -> apply(mod, fun, [conn])
      _ -> conn
    end
  end
  def not_found_handler(%Phoenix.LiveView.Socket{} = socket) do
    {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
  end

  @doc """
  The default handler for when a resource is not authorized.
  For Plug based authorization it will use the global `:unauthorized_handler` or return the conn.

  For LiveView base authorization it will halt socket.
  """
  @impl true
  def unauthorized_handler(%Plug.Conn{} = conn) do
    case Application.get_env(:canary, :unauthorized_handler) do
      {mod, fun} -> apply(mod, fun, [conn])
      _ -> conn
    end
  end
  def unauthorized_handler(%Phoenix.LiveView.Socket{} = socket) do
    {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
  end
end
