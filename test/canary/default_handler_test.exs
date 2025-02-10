defmodule CustomHandlers do
  def not_found_handler(conn) do
    conn
    |> Plug.Conn.assign(:legacy_error_handler, true)
  end

  def unauthorized_handler(conn) do
    conn
    |> Plug.Conn.assign(:legacy_error_handler, true)
  end
end

defmodule DefaultHandlerTest do
  use ExUnit.Case, async: false
  import Plug.Adapters.Test.Conn, only: [conn: 4]

  describe "not_found_handler/1" do
    test "calls the global :not_found_handler for plug based authorization" do
      Application.put_env(:canary, :not_found_handler, {CustomHandlers, :not_found_handler})

      params = %{"id" => "30"}

      conn =
        conn(
          %Plug.Conn{private: %{phoenix_action: :show}},
          :get,
          "/posts/30",
          params
        )
        |> Canary.DefaultHandler.not_found_handler()

      assert conn.assigns[:legacy_error_handler] == true
      assert conn.assigns[:post] == nil
    end

    test "returns conn when error_handler is not defined" do
      Application.put_env(:canary, :not_found_handler, nil)

      params = %{"id" => "30"}

      conn =
        conn(
          %Plug.Conn{private: %{phoenix_action: :show}},
          :get,
          "/posts/30",
          params
        )
        |> Canary.DefaultHandler.not_found_handler()

      assert conn.assigns[:post] == nil
      refute conn.assigns[:legacy_error_handler] == true
    end

    test "halts the socket for liveview based authorization" do
      assert {:halt, socket} =
               %Phoenix.LiveView.Socket{assigns: %{}}
               |> Canary.DefaultHandler.not_found_handler()

      assert {:redirect, %{to: "/"}} = socket.redirected
    end
  end

  describe "unauthorized_handler/1" do
    test "calls the global :not_found_handler for plug based authorization" do
      Application.put_env(:canary, :unauthorized_handler, {CustomHandlers, :unauthorized_handler})

      params = %{"id" => "30"}

      conn =
        conn(
          %Plug.Conn{private: %{phoenix_action: :show}},
          :get,
          "/posts/30",
          params
        )
        |> Canary.DefaultHandler.unauthorized_handler()

      assert conn.assigns[:legacy_error_handler] == true
      assert conn.assigns[:post] == nil
    end

    test "returns conn when error_handler is not defined" do
      Application.put_env(:canary, :unauthorized_handler, nil)

      params = %{"id" => "30"}

      conn =
        conn(
          %Plug.Conn{private: %{phoenix_action: :show}},
          :get,
          "/posts/30",
          params
        )
        |> Canary.DefaultHandler.unauthorized_handler()

      assert conn.assigns[:post] == nil
      refute conn.assigns[:legacy_error_handler] == true
    end

    test "halts the socket for liveview based authorization" do
      assert {:halt, socket} =
               %Phoenix.LiveView.Socket{assigns: %{}}
               |> Canary.DefaultHandler.unauthorized_handler()

      assert {:redirect, %{to: "/"}} = socket.redirected
    end
  end
end
