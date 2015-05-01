defmodule User do
  defstruct id: 1
end

defmodule Post do
  defstruct id: 1, user_id: 1
end

defmodule Repo do
  def get(User, 1), do: %User{}
  def get(User, _), do: nil

  def get(Post, 1), do: %Post{}
  def get(Post, 2), do: %Post{user_id: 2 }
  def get(Post, _), do: nil
end

defimpl Canada.Can, for: User do
  def can?(%User{id: user_id}, action, %Post{user_id: user_id})
  when action in [:show], do: true

  def can?(%User{}, _, _), do: false
end

defmodule CanaryTest do
  use Canary

  import Plug.Adapters.Test.Conn, only: [conn: 4]

  use ExUnit.Case, async: true

  @moduletag timeout: 100000000

  Application.put_env :canary, :repo, Repo

  test "it loads the load resource correctly" do
    opts = %{repo: Repo, model: Post}

    # when the resource with the id can be fetched
    params = %{"id" => 1}
    conn = conn(%Plug.Conn{private: %{}}, :get, "/posts/1", params)
    expected = %{conn | assigns: Map.put(conn.assigns, :loaded_resource, %Post{id: 1})}

    assert load_resource(conn, opts) == expected

    # when the resource with the id cannot be fetched
    params = %{"id" => 3}
    conn = conn(%Plug.Conn{private: %{}}, :get, "/posts/3", params)
    expected = %{conn | assigns: Map.put(conn.assigns, :loaded_resource, nil)}

    assert load_resource(conn, opts) == expected
  end

  test "it authorizes the resource correctly" do
    opts = %{repo: Repo, model: Post}

    # when the current user can access the give resource
    # and the action is a phoenix action
    params = %{"id" => 1}
    conn = conn(
      %Plug.Conn{
        private: %{phoenix_action: :show},
        assigns: %{current_user: %User{id: 1}}
      },
      :get,
      "/posts/1",
      params
    )
    expected = %{conn | assigns: Map.put(conn.assigns, :authorized, true)}

    assert authorize_resource(conn, opts) == expected


    # when both conn.assigns.action and conn.private.phoenix_action are defined
    # it uses conn.assigns.action for authorization
    params = %{"id" => 1}
    conn = conn(
      %Plug.Conn{
        private: %{phoenix_action: :show},
        assigns: %{current_user: %User{id: 1}, action: :unauthorized}
      },
      :get,
      "/posts/1",
      params
    )
    expected = %{conn | assigns: Map.put(conn.assigns, :authorized, false)}

    assert authorize_resource(conn, opts) == expected


    # when the current user cannot access the give resource
    params = %{"id" => 2}
    conn = conn(
      %Plug.Conn{
        private: %{},
        assigns: %{current_user: %User{id: 1}, action: :show}
      },
      :get,
      "/posts/2",
      params
    )
    expected = %{conn | assigns: Map.put(conn.assigns, :authorized, false)}

    assert authorize_resource(conn, opts) == expected
  end

  test "it loads and authorizes the resource correctly" do
    opts = %{repo: Repo, model: Post}

    # when the current user can access the given resource
    # and the resource can be loaded
    params = %{"id" => 1}
    conn = conn(
      %Plug.Conn{
        private: %{phoenix_action: :show},
        assigns: %{current_user: %User{id: 1}}
      },
      :get,
      "/posts/1",
      params
    )
    expected = %{conn | assigns: Map.put(conn.assigns, :authorized, true)}
    expected = %{expected | assigns: Map.put(expected.assigns, :loaded_resource, %Post{id: 1, user_id: 1})}

    assert load_and_authorize_resource(conn, opts) == expected


    # when the current user cannot access the give resource
    params = %{"id" => 2}
    conn = conn(
      %Plug.Conn{
        private: %{},
        assigns: %{current_user: %User{id: 1}, action: :show}
      },
      :get,
      "/posts/2",
      params
    )
    expected = %{conn | assigns: Map.put(conn.assigns, :authorized, false)}
    expected = %{expected | assigns: Map.put(expected.assigns, :loaded_resource, nil)}

    assert load_and_authorize_resource(conn, opts) == expected


    # when the given resource cannot be loaded
    params = %{"id" => 3}
    conn = conn(
      %Plug.Conn{
        private: %{},
        assigns: %{current_user: %User{id: 1}, action: :show}
      },
      :get,
      "/posts/1",
      params
    )
    expected = %{conn | assigns: Map.put(conn.assigns, :authorized, false)}
    expected = %{expected | assigns: Map.put(expected.assigns, :loaded_resource, nil)}

    assert load_and_authorize_resource(conn, opts) == expected
  end
end
