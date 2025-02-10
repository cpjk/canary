defmodule Canary.PlugsTest do
  import Canary.Plugs

  import Plug.Adapters.Test.Conn, only: [conn: 4]

  use ExUnit.Case, async: true

  @moduletag timeout: 100_000_000

  Application.put_env(:canary, :repo, Repo)
  Application.delete_env(:canary, :error_handler)

  test "it loads the resource correctly" do
    opts = [model: Post]

    # when the resource with the id can be fetched
    params = %{"id" => "1"}
    conn = conn(%Plug.Conn{private: %{phoenix_action: :show}}, :get, "/posts/1", params)
    expected = %{conn | assigns: Map.put(conn.assigns, :post, %Post{id: 1})}

    assert load_resource(conn, opts) == expected

    # when a resource of the desired type is already present in conn.assigns
    # it does not clobber the old resource
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{private: %{phoenix_action: :show}, assigns: %{post: %Post{id: 2}}},
        :get,
        "/posts/1",
        params
      )

    expected = Plug.Conn.assign(conn, :post, %Post{id: 2})

    assert load_resource(conn, opts) == expected

    # when a resource of the desired type is already present in conn.assigns and the action is :index
    # it does not clobber the old resource
    params = %{}

    conn =
      conn(
        %Plug.Conn{private: %{phoenix_action: :index}, assigns: %{posts: [%Post{id: 2}]}},
        :get,
        "/posts",
        params
      )

    expected = Plug.Conn.assign(conn, :posts, [%Post{id: 2}])

    assert load_resource(conn, opts) == expected

    # when a resource of a different type is already present in conn.assigns
    # it replaces that resource with the desired resource
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{private: %{phoenix_action: :show}, assigns: %{post: %User{id: 2}}},
        :get,
        "/posts/1",
        params
      )

    expected = Plug.Conn.assign(conn, :post, %Post{id: 1})

    assert load_resource(conn, opts) == expected

    # when a resource of a different type is already present in conn.assigns and the action is :index
    # it replaces that resource with the desired resource
    params = %{}

    conn =
      conn(
        %Plug.Conn{private: %{phoenix_action: :index}, assigns: %{posts: [%User{id: 2}]}},
        :get,
        "/posts",
        params
      )

    expected = Plug.Conn.assign(conn, :posts, [%Post{id: 1}, %Post{id: 2, user_id: 2}])

    assert load_resource(conn, opts) == expected

    # when the resource with the id cannot be fetched
    params = %{"id" => "3"}
    conn = conn(%Plug.Conn{private: %{phoenix_action: :show}}, :get, "/posts/3", params)
    expected = Plug.Conn.assign(conn, :post, nil)

    assert load_resource(conn, opts) == expected

    # when the action is "index"
    params = %{}
    conn = conn(%Plug.Conn{private: %{phoenix_action: :index}}, :get, "/posts", params)
    expected = Plug.Conn.assign(conn, :posts, [%Post{id: 1}, %Post{id: 2, user_id: 2}])

    assert load_resource(conn, opts) == expected

    # when the action is "new"
    params = %{}
    conn = conn(%Plug.Conn{private: %{phoenix_action: :new}}, :get, "/posts/new", params)
    expected = Plug.Conn.assign(conn, :post, nil)

    assert load_resource(conn, opts) == expected

    # when the action is "create"
    params = %{}
    conn = conn(%Plug.Conn{private: %{phoenix_action: :create}}, :post, "/posts/create", params)
    expected = Plug.Conn.assign(conn, :post, nil)

    assert load_resource(conn, opts) == expected
  end

  test "it loads the resource correctly with opts[:id_name] specified" do
    opts = [model: Post, id_name: "post_id"]

    # when id param is correct
    params = %{"post_id" => 1}
    conn = conn(%Plug.Conn{private: %{phoenix_action: :show}}, :get, "/posts/1", params)
    expected = Plug.Conn.assign(conn, :post, %Post{id: 1})

    assert load_resource(conn, opts) == expected
  end

  test "it loads the resource correctly with opts[:id_field] specified" do
    opts = [model: Post, id_name: "slug", id_field: "slug"]

    # when slug param is correct
    params = %{"slug" => "slug1"}
    conn = conn(%Plug.Conn{private: %{phoenix_action: :show}}, :get, "/posts/slug1", params)
    expected = Plug.Conn.assign(conn, :post, %Post{id: 1, slug: "slug1"})

    assert load_resource(conn, opts) == expected
  end

  test "it loads the resource correctly with opts[:persisted] specified on :index action" do
    opts = [model: User, id_name: "user_id", persisted: true]

    params = %{"user_id" => 1}
    conn = conn(%Plug.Conn{private: %{phoenix_action: :index}}, :get, "/users/1/posts", params)
    expected = Plug.Conn.assign(conn, :user, %User{id: 1})

    assert load_resource(conn, opts) == expected
  end

  test "it loads the resource correctly with opts[:persisted] specified on :new action" do
    opts = [model: User, id_name: "user_id", persisted: true]

    params = %{"user_id" => 1}
    conn = conn(%Plug.Conn{private: %{phoenix_action: :new}}, :get, "/users/1/posts/new", params)
    expected = Plug.Conn.assign(conn, :user, %User{id: 1})

    assert load_resource(conn, opts) == expected
  end

  test "it loads the resource correctly with opts[:persisted] specified on :create action" do
    opts = [model: User, id_name: "user_id", persisted: true]

    params = %{"user_id" => "1"}
    conn = conn(%Plug.Conn{private: %{phoenix_action: :create}}, :post, "/users/1/posts", params)
    expected = Plug.Conn.assign(conn, :user, %User{id: 1})

    assert load_resource(conn, opts) == expected
  end

  test "it calls the specified action when not_found with opts[:required] specified on :new action" do
    opts = [model: Post, not_found_handler: {Helpers, :not_found_handler}, required: true]

    params = %{"id" => "3"}

    conn =
      conn(
        %Plug.Conn{assigns: %{post: nil}, private: %{phoenix_action: :new}},
        :get,
        "/posts/3/new",
        params
      )

    expected = Helpers.not_found_handler(conn)

    assert load_resource(conn, opts) == expected
  end

  test "it calls the specified action when not_found with opts[:required] specified on :create action" do
    opts = [model: Post, not_found_handler: {Helpers, :not_found_handler}, required: true]

    params = %{"id" => "3"}

    conn =
      conn(
        %Plug.Conn{assigns: %{post: nil}, private: %{phoenix_action: :index}},
        :post,
        "/posts/3/new",
        params
      )

    expected = Helpers.not_found_handler(conn)

    assert load_resource(conn, opts) == expected
  end

  test "it calls the specified action when not_found with opts[:required] specified on :index action" do
    opts = [model: Post, not_found_handler: {Helpers, :not_found_handler}, required: true]

    params = %{"id" => "3"}

    conn =
      conn(
        %Plug.Conn{assigns: %{post: nil}, private: %{phoenix_action: :index}},
        :get,
        "/posts/3",
        params
      )

    expected = Helpers.not_found_handler(conn)

    assert load_resource(conn, opts) == expected
  end

  test "it authorizes the resource correctly" do
    opts = [model: Post]

    # when the action is "new"
    params = %{}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :new},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/new",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_resource(conn, opts) == expected

    # when the action is "create"
    params = %{}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :create},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/create",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_resource(conn, opts) == expected

    # when the action is "index"
    params = %{}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :index},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_resource(conn, opts) == expected

    # when the action is a phoenix action
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/1",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_resource(conn, opts) == expected

    # when the current user can access the given resource
    # and the action is specified in conn.assigns.canary_action
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{},
          assigns: %{current_user: %User{id: 1}, canary_action: :show}
        },
        :get,
        "/posts/1",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_resource(conn, opts) == expected

    # when both conn.assigns.canary_action and conn.private.phoenix_action are defined
    # it uses conn.assigns.canary_action for authorization
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 1}, canary_action: :unauthorized}
        },
        :get,
        "/posts/1",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, false)

    assert authorize_resource(conn, opts) == expected

    # when the current user cannot access the given resource
    params = %{"id" => "2"}

    conn =
      conn(
        %Plug.Conn{
          private: %{},
          assigns: %{current_user: %User{id: 1}, canary_action: :show}
        },
        :get,
        "/posts/2",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, false)

    assert authorize_resource(conn, opts) == expected

    # when the resource of the desired type already exists in conn.assigns,
    # it authorizes for that resource
    params = %{"id" => "2"}

    conn =
      conn(
        %Plug.Conn{
          private: %{},
          assigns: %{current_user: %User{id: 1}, canary_action: :show, post: %Post{user_id: 1}}
        },
        :get,
        "/posts/2",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_resource(conn, opts) == expected

    # when the resource of a different type already exists in conn.assigns,
    # it authorizes for the desired resource
    params = %{"id" => "2"}

    conn =
      conn(
        %Plug.Conn{
          private: %{},
          assigns: %{current_user: %User{id: 1}, canary_action: :show, post: %User{}}
        },
        :get,
        "/posts/2",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, false)

    assert authorize_resource(conn, opts) == expected

    # when current_user is nil
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{},
          assigns: %{current_user: nil, canary_action: :create}
        },
        :post,
        "/posts",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, false)

    assert authorize_resource(conn, opts) == expected
  end

  test "it authorizes the resource correctly when using :id_field option" do
    opts = [model: Post, id_field: "slug", id_name: "slug"]

    # when the action is "new"
    params = %{}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :new},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/new",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_resource(conn, opts) == expected

    # when the action is "create"
    params = %{}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :create},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/create",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_resource(conn, opts) == expected

    # when the action is "index"
    params = %{}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :index},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_resource(conn, opts) == expected

    # when the action is a phoenix action
    params = %{"slug" => "slug1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/slug1",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_resource(conn, opts) == expected

    # when the current user can access the given resource
    # and the action is specified in conn.assigns.canary_action
    params = %{"slug" => "slug1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{},
          assigns: %{current_user: %User{id: 1}, canary_action: :show}
        },
        :get,
        "/posts/slug1",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_resource(conn, opts) == expected

    # when both conn.assigns.canary_action and conn.private.phoenix_action are defined
    # it uses conn.assigns.canary_action for authorization
    params = %{"slug" => "slug1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 1}, canary_action: :unauthorized}
        },
        :get,
        "/posts/slug1",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, false)

    assert authorize_resource(conn, opts) == expected

    # when the current user cannot access the given resource
    params = %{"slug" => "slug2"}

    conn =
      conn(
        %Plug.Conn{
          private: %{},
          assigns: %{current_user: %User{id: 1}, canary_action: :show}
        },
        :get,
        "/posts/slug2",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, false)

    assert authorize_resource(conn, opts) == expected

    # when the resource of the desired type already exists in conn.assigns,
    # it authorizes for that resource
    params = %{"slug" => "slug2"}

    conn =
      conn(
        %Plug.Conn{
          private: %{},
          assigns: %{current_user: %User{id: 1}, canary_action: :show, post: %Post{user_id: 1}}
        },
        :get,
        "/posts/slug2",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_resource(conn, opts) == expected

    # when the resource of a different type already exists in conn.assigns,
    # it authorizes for the desired resource
    params = %{"slug" => "slug2"}

    conn =
      conn(
        %Plug.Conn{
          private: %{},
          assigns: %{current_user: %User{id: 1}, canary_action: :show, post: %User{}}
        },
        :get,
        "/posts/slug2",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, false)

    assert authorize_resource(conn, opts) == expected

    # when current_user is nil
    params = %{"slug" => "slug1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{},
          assigns: %{current_user: nil, canary_action: :create}
        },
        :post,
        "/posts",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, false)

    assert authorize_resource(conn, opts) == expected
  end

  test "it authorizes the resource correctly with opts[:persisted] specified on :index action" do
    opts = [model: Post, id_name: "post_id", persisted: true]

    params = %{"post_id" => 2}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :index},
          assigns: %{current_user: %User{id: 2}}
        },
        :get,
        "/posts/post_id/comments",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_resource(conn, opts) == expected
  end

  test "it authorizes the resource correctly with opts[:persisted] specified on :new action" do
    opts = [model: Post, id_name: "post_id", persisted: true]

    params = %{"post_id" => 2}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :new},
          assigns: %{current_user: %User{id: 2}}
        },
        :get,
        "/posts/post_id/comments/new",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_resource(conn, opts) == expected
  end

  test "it authorizes the resource correctly with opts[:persisted] specified on :create action" do
    opts = [model: Post, id_name: "post_id", persisted: true]

    params = %{"post_id" => "2"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :create},
          assigns: %{current_user: %User{id: 2}}
        },
        :post,
        "/posts/post_id/comments",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_resource(conn, opts) == expected
  end

  test "it loads and authorizes the resource correctly" do
    opts = [model: Post]

    # when the current user can access the given resource
    # and the resource can be loaded
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/1",
        params
      )

    expected =
      conn
      |> Plug.Conn.assign(:authorized, true)
      |> Plug.Conn.assign(:post, %Post{id: 1, user_id: 1})

    assert load_and_authorize_resource(conn, opts) == expected

    # when the current user cannot access the given resource
    params = %{"id" => "2"}

    conn =
      conn(
        %Plug.Conn{
          private: %{},
          assigns: %{current_user: %User{id: 1}, canary_action: :show}
        },
        :get,
        "/posts/2",
        params
      )

    expected =
      conn
      |> Plug.Conn.assign(:authorized, false)
      |> Plug.Conn.assign(:post, nil)

    assert load_and_authorize_resource(conn, opts) == expected

    # when a resource of the desired type is already present in conn.assigns
    # it does not load a new resource
    params = %{"id" => "2"}

    conn =
      conn(
        %Plug.Conn{
          private: %{},
          assigns: %{current_user: %User{id: 1}, canary_action: :show, post: %Post{user_id: 1}}
        },
        :get,
        "/posts/2",
        params
      )

    expected =
      conn
      |> Plug.Conn.assign(:authorized, true)
      |> Plug.Conn.assign(:post, %Post{user_id: 1})

    assert load_and_authorize_resource(conn, opts) == expected

    # when a resource of the a different type is already present in conn.assigns
    # it loads and authorizes for the desired resource
    params = %{"id" => "2"}

    conn =
      conn(
        %Plug.Conn{
          private: %{},
          assigns: %{current_user: %User{id: 1}, canary_action: :show, post: %User{id: 1}}
        },
        :get,
        "/posts/2",
        params
      )

    expected =
      conn
      |> Plug.Conn.assign(:authorized, false)
      |> Plug.Conn.assign(:post, nil)

    assert load_and_authorize_resource(conn, opts) == expected

    # when the given resource cannot be loaded
    params = %{"id" => "3"}

    conn =
      conn(
        %Plug.Conn{
          private: %{},
          assigns: %{current_user: %User{id: 1}, canary_action: :show}
        },
        :get,
        "/posts/1",
        params
      )

    expected =
      conn
      |> Plug.Conn.assign(:authorized, false)
      |> Plug.Conn.assign(:post, nil)

    assert load_and_authorize_resource(conn, opts) == expected
  end

  test "it loads and authorizes the resource correctly when using :id_field option" do
    opts = [model: Post, id_field: "slug", id_name: "slug"]

    # when the current user can access the given resource
    # and the resource can be loaded
    params = %{"slug" => "slug1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/slug1",
        params
      )

    expected =
      conn
      |> Plug.Conn.assign(:authorized, true)
      |> Plug.Conn.assign(:post, %Post{id: 1, slug: "slug1", user_id: 1})

    assert load_and_authorize_resource(conn, opts) == expected

    # when the current user cannot access the given resource
    params = %{"slug" => "slug2"}

    conn =
      conn(
        %Plug.Conn{
          private: %{},
          assigns: %{current_user: %User{id: 1}, canary_action: :show}
        },
        :get,
        "/posts/slug2",
        params
      )

    expected =
      conn
      |> Plug.Conn.assign(:authorized, false)
      |> Plug.Conn.assign(:post, nil)

    assert load_and_authorize_resource(conn, opts) == expected

    # when a resource of the desired type is already present in conn.assigns
    # it does not load a new resource
    params = %{"slug" => "slug2"}

    conn =
      conn(
        %Plug.Conn{
          private: %{},
          assigns: %{current_user: %User{id: 1}, canary_action: :show, post: %Post{user_id: 1}}
        },
        :get,
        "/posts/slug2",
        params
      )

    expected =
      conn
      |> Plug.Conn.assign(:authorized, true)
      |> Plug.Conn.assign(:post, %Post{user_id: 1})

    assert load_and_authorize_resource(conn, opts) == expected

    # when a resource of the a different type is already present in conn.assigns
    # it loads and authorizes for the desired resource
    params = %{"slug" => "slug2"}

    conn =
      conn(
        %Plug.Conn{
          private: %{},
          assigns: %{current_user: %User{id: 1}, canary_action: :show, post: %User{id: 1}}
        },
        :get,
        "/posts/slug2",
        params
      )

    expected =
      conn
      |> Plug.Conn.assign(:authorized, false)
      |> Plug.Conn.assign(:post, nil)

    assert load_and_authorize_resource(conn, opts) == expected

    # when the given resource cannot be loaded
    params = %{"slug" => "slug3"}

    conn =
      conn(
        %Plug.Conn{
          private: %{},
          assigns: %{current_user: %User{id: 1}, canary_action: :show}
        },
        :get,
        "/posts/slug3",
        params
      )

    expected =
      conn
      |> Plug.Conn.assign(:authorized, false)
      |> Plug.Conn.assign(:post, nil)

    assert load_and_authorize_resource(conn, opts) == expected
  end

  test "it loads and authorizes the resource correctly with opts[:persisted] specified on :index action" do
    opts = [model: Post, id_name: "post_id", persisted: true]

    params = %{"post_id" => 2}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :index},
          assigns: %{current_user: %User{id: 2}}
        },
        :get,
        "/posts/2/comments",
        params
      )

    expected =
      conn
      |> Plug.Conn.assign(:authorized, true)
      |> Plug.Conn.assign(:post, %Post{id: 2, user_id: 2})

    assert load_and_authorize_resource(conn, opts) == expected
  end

  test "it loads and authorizes the resource correctly with opts[:persisted] specified on :new action" do
    opts = [model: Post, id_name: "post_id", persisted: true]

    params = %{"post_id" => 2}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :new},
          assigns: %{current_user: %User{id: 2}}
        },
        :get,
        "/posts/2/comments/new",
        params
      )

    expected =
      conn
      |> Plug.Conn.assign(:authorized, true)
      |> Plug.Conn.assign(:post, %Post{id: 2, user_id: 2})

    assert load_and_authorize_resource(conn, opts) == expected
  end

  test "it loads and authorizes the resource correctly with opts[:persisted] specified on :create action" do
    opts = [model: Post, id_name: "post_id", persisted: true]

    params = %{"post_id" => "2"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :create},
          assigns: %{current_user: %User{id: 2}}
        },
        :create,
        "/posts/2/comments",
        params
      )

    expected =
      conn
      |> Plug.Conn.assign(:authorized, true)
      |> Plug.Conn.assign(:post, %Post{id: 2, user_id: 2})

    assert load_and_authorize_resource(conn, opts) == expected
  end

  test "it only loads the resource when the action is in opts[:only]" do
    # when the action is in opts[:only]
    opts = [model: Post, only: :show]
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/1",
        params
      )

    expected = Plug.Conn.assign(conn, :post, %Post{id: 1})

    assert load_resource(conn, opts) == expected

    # when the action is not opts[:only]
    opts = [model: Post, only: :other]
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/1",
        params
      )

    expected = conn

    assert load_resource(conn, opts) == expected
  end

  test "it only authorizes actions in opts[:only]" do
    # when the action is in opts[:only]
    opts = [model: Post, only: :show]
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/1",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)
    assert authorize_resource(conn, opts) == expected

    # when the action is not opts[:only]
    opts = [model: Post, only: :other]
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/1",
        params
      )

    expected = conn

    assert authorize_resource(conn, opts) == expected
  end

  test "it only loads and authorizes the resource for actions in opts[:only]" do
    # when the action is in opts[:only]
    opts = [model: Post, only: :show]
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/1",
        params
      )

    expected =
      conn
      |> Plug.Conn.assign(:authorized, true)
      |> Plug.Conn.assign(:post, %Post{id: 1, user_id: 1})

    assert load_and_authorize_resource(conn, opts) == expected

    # when the action is not opts[:only]
    opts = [model: Post, only: :other]
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/1",
        params
      )

    expected = conn

    assert load_and_authorize_resource(conn, opts) == expected
  end

  test "it raises when both opts[:only] and opts[:except] are specified" do
    # when the plug is load_resource
    opts = [model: Post, only: :show, except: :index]
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/1",
        params
      )

    expected = conn

    assert_raise ArgumentError, fn ->
      load_resource(conn, opts) == expected
    end

    # when the plug is authorize_resource
    opts = [model: Post, only: :show, except: :index]
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/1",
        params
      )

    expected = conn


    assert_raise ArgumentError, fn ->
      authorize_resource(conn, opts) == expected
    end

    # when the plug is load_and_authorize_resource
    opts = [model: Post, only: :show, except: :index]
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/1",
        params
      )

    expected = conn

    assert_raise ArgumentError, fn ->
      load_and_authorize_resource(conn, opts) == expected
    end
  end

  test "it correctly skips authorization for exempt actions" do
    # when the action is exempt
    opts = [model: Post, except: :show]
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/1",
        params
      )

    expected = conn

    assert authorize_resource(conn, opts) == expected

    # when the action is not exempt
    opts = [model: Post]
    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_resource(conn, opts) == expected
  end

  test "it correctly skips loading resources for exempt actions" do
    # when the action is exempt
    opts = [model: Post, except: :show]
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/1",
        params
      )

    expected = conn
    assert load_resource(conn, opts) == expected

    # when the action is not exempt
    opts = [model: Post]
    expected = Plug.Conn.assign(conn, :post, %Post{id: 1, user_id: 1})
    assert load_resource(conn, opts) == expected
  end

  test "it correctly skips load_and_authorize_resource for exempt actions" do
    # when the action is exempt
    opts = [model: Post, except: :show]
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/1",
        params
      )

    expected = conn
    assert load_and_authorize_resource(conn, opts) == expected

    # when the action is not exempt
    opts = [model: Post]

    expected =
      conn
      |> Plug.Conn.assign(:authorized, true)
      |> Plug.Conn.assign(:post, %Post{id: 1, user_id: 1})

    assert load_and_authorize_resource(conn, opts) == expected
  end

  test "it loads the resource into a key specified by the :as option" do
    opts = [model: Post, as: :some_key]

    # when the resource with the id can be fetched
    params = %{"id" => "1"}
    conn = conn(%Plug.Conn{private: %{phoenix_action: :show}}, :get, "/posts/1", params)
    expected = Plug.Conn.assign(conn, :some_key, %Post{id: 1})

    assert load_resource(conn, opts) == expected
  end

  test "it authorizes the resource correctly when the :as key is specified" do
    opts = [model: Post, as: :some_key]

    # when the action is "new"
    params = %{}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :new},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/new",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_resource(conn, opts) == expected
    # need to check that it works for authorization as well, and for load_and_authorize_resource
  end

  test "it loads and authorizes the resource correctly when the :as key is specified" do
    opts = [model: Post, as: :some_key]

    # when the current user can access the given resource
    # and the resource can be loaded
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/1",
        params
      )

    expected =
      conn
      |> Plug.Conn.assign(:authorized, true)
      |> Plug.Conn.assign(:some_key, %Post{id: 1, user_id: 1})

    assert load_and_authorize_resource(conn, opts) == expected
  end

  test "when the :as key is not specified, it loads the resource into a key inferred from the model name" do
    opts = [model: Post]

    # when the resource with the id can be fetched
    params = %{"id" => "1"}
    conn = conn(%Plug.Conn{private: %{phoenix_action: :show}}, :get, "/posts/1", params)
    expected = Plug.Conn.assign(conn, :post, %Post{id: 1})

    assert load_resource(conn, opts) == expected
  end

  test "when unauthorized, it calls the specified action" do
    opts = [model: Post, unauthorized_handler: {Helpers, :unauthorized_handler}]

    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{assigns: %{current_user: %User{id: 2}}, private: %{phoenix_action: :show}},
        :get,
        "/posts/1",
        params
      )

    expected =
      conn
      |> Plug.Conn.assign(:authorized, false)
      |> Helpers.unauthorized_handler()

    assert authorize_resource(conn, opts) == expected
  end

  test "when not_found, it calls the specified action" do
    opts = [model: Post, not_found_handler: {Helpers, :not_found_handler}]

    params = %{"id" => "3"}

    conn =
      conn(
        %Plug.Conn{assigns: %{post: nil}, private: %{phoenix_action: :show}},
        :get,
        "/posts/3",
        params
      )

    expected = Helpers.not_found_handler(conn)

    assert load_resource(conn, opts) == expected
  end

  test "when unauthorized and resource not found, it calls the specified authorization handler first" do
    opts = [
      model: Post,
      not_found_handler: {Helpers, :not_found_handler},
      unauthorized_handler: {Helpers, :unauthorized_handler}
    ]

    params = %{"id" => "3"}

    conn =
      conn(
        %Plug.Conn{assigns: %{current_user: %User{id: 2}}, private: %{phoenix_action: :show}},
        :get,
        "/posts/3",
        params
      )

    expected =
      conn
      |> Plug.Conn.assign(:authorized, false)
      |> Plug.Conn.assign(:post, nil)
      |> Helpers.unauthorized_handler()

    assert load_and_authorize_resource(conn, opts) == expected
  end

  test "when the authorization handler does not halt the request, it calls the not found handler if specified" do
    opts = [
      model: Post,
      not_found_handler: {Helpers, :not_found_handler},
      unauthorized_handler: {Helpers, :non_halting_unauthorized_handler}
    ]

    params = %{"id" => "3"}

    conn =
      conn(
        %Plug.Conn{assigns: %{current_user: %User{id: 2}}, private: %{phoenix_action: :show}},
        :get,
        "/posts/3",
        params
      )

    expected =
      conn
      |> Plug.Conn.assign(:authorized, false)
      |> Plug.Conn.assign(:post, nil)
      |> Helpers.non_halting_unauthorized_handler()
      |> Helpers.not_found_handler()

    assert load_and_authorize_resource(conn, opts) == expected
  end

  defmodule UnauthorizedHandlerConfigured do
    use ExUnit.Case, async: false

    test "when unauthorized, it calls the configured action" do
      Application.put_env(:canary, :unauthorized_handler, {Helpers, :unauthorized_handler})
      opts = [model: Post]

      params = %{"id" => "1"}

      conn =
        conn(
          %Plug.Conn{assigns: %{current_user: %User{id: 2}}, private: %{phoenix_action: :show}},
          :get,
          "/posts/1",
          params
        )

      expected =
        conn
        |> Plug.Conn.assign(:authorized, false)
        |> Helpers.unauthorized_handler()

      assert authorize_resource(conn, opts) == expected
    end

    test "when unauthorized and resource not found, it calls the configured authorization handler first" do
      Application.put_env(:canary, :unauthorized_handler, {Helpers, :unauthorized_handler})
      opts = [model: Post]

      params = %{"id" => "3"}

      conn =
        conn(
          %Plug.Conn{assigns: %{current_user: %User{id: 2}}, private: %{phoenix_action: :show}},
          :get,
          "/posts/3",
          params
        )

      expected =
        conn
        |> Plug.Conn.assign(:authorized, false)
        |> Plug.Conn.assign(:post, nil)
        |> Helpers.unauthorized_handler()

      assert load_and_authorize_resource(conn, opts) == expected
    end
  end

  defmodule UnauthorizedHandlerConfiguredAndSpecified do
    use ExUnit.Case, async: false

    test "when unauthorized, it calls the opt-specified action rather than the configured action" do
      # should not be called
      Application.put_env(:canary, :unauthorized_handler, {Helpers, :does_not_exist})
      opts = [model: Post, unauthorized_handler: {Helpers, :unauthorized_handler}]

      params = %{"id" => "1"}

      conn =
        conn(
          %Plug.Conn{assigns: %{current_user: %User{id: 2}}, private: %{phoenix_action: :show}},
          :get,
          "/posts/1",
          params
        )

      expected =
        conn
        |> Helpers.unauthorized_handler()
        |> Plug.Conn.assign(:authorized, false)

      assert authorize_resource(conn, opts) == expected
    end
  end

  defmodule NotFoundHandlerConfigured do
    use ExUnit.Case, async: false

    test "when not_found, it calls the configured action" do
      Application.put_env(:canary, :not_found_handler, {Helpers, :not_found_handler})
      opts = [model: Post]

      params = %{"id" => "4"}
      conn = conn(%Plug.Conn{private: %{phoenix_action: :show}}, :get, "/posts/4", params)

      expected =
        conn
        |> Helpers.not_found_handler()
        |> Plug.Conn.assign(:post, nil)

      assert load_resource(conn, opts) == expected
    end
  end

  defmodule NotFoundHandlerConfiguredAndSpecified do
    use ExUnit.Case, async: false

    test "when not_found, it calls the opt-specified action rather than the configured action" do
      # should not be called
      Application.put_env(:canary, :not_found_handler, {Helpers, :does_not_exist})
      opts = [model: Post, not_found_handler: {Helpers, :not_found_handler}]

      params = %{"id" => "4"}
      conn = conn(%Plug.Conn{private: %{phoenix_action: :show}}, :get, "/posts/4", params)

      expected =
        conn
        |> Helpers.not_found_handler()
        |> Plug.Conn.assign(:post, nil)

      assert load_resource(conn, opts) == expected
    end
  end

  defmodule CurrentUser do
    use ExUnit.Case, async: true

    defmodule ApplicationConfig do
      use ExUnit.Case, async: false
      import Mock

      test_with_mock "it uses the current_user name configured", Application, [:passthrough],
        get_env: fn _, _, _ -> :current_admin end do
        # when the user configured with opts
        opts = [model: Post, except: :show]
        params = %{"id" => "1"}

        conn =
          conn(
            %Plug.Conn{
              private: %{phoenix_action: :show},
              assigns: %{current_admin: %User{id: 1}}
            },
            :get,
            "/posts/1",
            params
          )

        expected = conn

        assert authorize_resource(conn, opts) == expected
      end
    end

    test "it uses the current_user name in options" do
      # when the user configured with opts
      opts = [model: Post, current_user: :user]
      params = %{"id" => "1"}

      conn =
        conn(
          %Plug.Conn{
            private: %{phoenix_action: :show},
            assigns: %{user: %User{id: 1}, authorized: true}
          },
          :get,
          "/posts/1",
          params
        )

      expected = conn

      assert authorize_resource(conn, opts) == expected
    end

    test "it throws an error when the wrong current_user name is used" do
      # when the user configured with opts
      opts = [model: Post, current_user: :configured_current_user]
      params = %{"id" => "1"}

      conn =
        conn(
          %Plug.Conn{
            private: %{phoenix_action: :show},
            assigns: %{user: %User{id: 1}, authorized: true}
          },
          :get,
          "/posts/1",
          params
        )

      assert_raise KeyError, ~r/^key :configured_current_user not found in: %{/, fn ->
        authorize_resource(conn, opts)
      end
    end
  end

  defmodule Preload do
    use ExUnit.Case, async: true

    test "it loads the resource correctly when the :preload key is specified" do
      opts = [model: Post, preload: :user]

      # when the resource with the id can be fetched and the association exists
      params = %{"id" => "2"}
      conn = conn(%Plug.Conn{private: %{phoenix_action: :show}}, :get, "/posts/1", params)
      expected = Plug.Conn.assign(conn, :post, %Post{id: 2, user_id: 2, user: %User{id: 2}})

      assert load_resource(conn, opts) == expected

      # when the resource with the id can be fetched and the association does not exist
      params = %{"id" => "1"}
      conn = conn(%Plug.Conn{private: %{phoenix_action: :show}}, :get, "/posts/1", params)
      expected = Plug.Conn.assign(conn, :post, %Post{id: 1, user_id: 1, user: %User{id: 1}})

      assert load_resource(conn, opts) == expected

      # when the resource with the id cannot be fetched
      params = %{"id" => "3"}
      conn = conn(%Plug.Conn{private: %{phoenix_action: :show}}, :get, "/posts/3", params)
      expected = Plug.Conn.assign(conn, :post, nil)

      assert load_resource(conn, opts) == expected

      # when the action is "index"
      params = %{}
      conn = conn(%Plug.Conn{private: %{phoenix_action: :index}}, :get, "/posts", params)

      expected =
        Plug.Conn.assign(conn, :posts, [
          %Post{id: 1},
          %Post{id: 2, user_id: 2, user: %User{id: 2}}
        ])

      assert load_resource(conn, opts) == expected

      # when the action is "new"
      params = %{}
      conn = conn(%Plug.Conn{private: %{phoenix_action: :new}}, :get, "/posts/new", params)
      expected = Plug.Conn.assign(conn, :post, nil)

      assert load_resource(conn, opts) == expected
    end

    test "it authorizes the resource correctly when the :preload key is specified" do
      opts = [model: Post, preload: :user]

      # when the action is "edit"
      params = %{"id" => "2"}

      conn =
        conn(
          %Plug.Conn{
            private: %{phoenix_action: :edit},
            assigns: %{current_user: %User{id: 2}}
          },
          :get,
          "/posts/edit/2",
          params
        )

      expected = Plug.Conn.assign(conn, :authorized, true)

      assert authorize_resource(conn, opts) == expected

      # when the action is "index"
      params = %{}

      conn =
        conn(
          %Plug.Conn{
            private: %{phoenix_action: :index},
            assigns: %{current_user: %User{id: 1}}
          },
          :get,
          "/posts",
          params
        )

      expected = Plug.Conn.assign(conn, :authorized, true)

      assert authorize_resource(conn, opts) == expected
    end

    test "it loads and authorizes the resource correctly when the :preload key is specified" do
      opts = [model: Post, preload: :user]

      # when the current user can access the given resource
      # and the resource can be loaded and the association exists
      params = %{"id" => "2"}

      conn =
        conn(
          %Plug.Conn{
            private: %{phoenix_action: :show},
            assigns: %{current_user: %User{id: 2}}
          },
          :get,
          "/posts/2",
          params
        )

      expected =
        conn
        |> Plug.Conn.assign(:authorized, true)
        |> Plug.Conn.assign(:post, %Post{id: 2, user_id: 2, user: %User{id: 2}})

     assert load_and_authorize_resource(conn, opts) == expected

      # when the current user can access the given resource
      # and the resource can be loaded and the association does not exist
      params = %{"id" => "1"}

      conn =
        conn(
          %Plug.Conn{
            private: %{phoenix_action: :show},
            assigns: %{current_user: %User{id: 1}}
          },
          :get,
          "/posts/1",
          params
        )

      expected =
        conn
        |> Plug.Conn.assign(:authorized, true)
        |> Plug.Conn.assign(:post, %Post{id: 1, user_id: 1, user: %User{id: 1}})

      assert load_and_authorize_resource(conn, opts) == expected

      # when the action is "edit"
      params = %{"id" => "2"}

      conn =
        conn(
          %Plug.Conn{
            private: %{phoenix_action: :edit},
            assigns: %{current_user: %User{id: 2}}
          },
          :get,
          "/posts/edit/2",
          params
        )

      expected =
        conn
        |> Plug.Conn.assign(:authorized, true)
        |> Plug.Conn.assign(:post, %Post{id: 2, user_id: 2, user: %User{id: 2}})

      assert load_and_authorize_resource(conn, opts) == expected
    end
  end

  defmodule NonIdActions do
    use ExUnit.Case, async: true

    test "it throws an error when the non_id_actions is not a list" do
      # when opts[:non_id_actions] is set but not as a list
      opts = [model: Post, non_id_actions: :other_action]
      params = %{"id" => "1"}

      conn =
        conn(
          %Plug.Conn{
            private: %{phoenix_action: :other_action},
            assigns: %{current_user: %User{id: 1}, authorized: true}
          },
          :get,
          "/posts/other-action",
          params
        )

      assert_raise Protocol.UndefinedError, ~r/protocol Enumerable not implemented for /, fn ->
        authorize_resource(conn, opts)
      end
    end

    test "it authorizes the resource correctly when non_id_actions is a list" do
      # when opts[:non_id_actions] is set as a list
      opts = [model: Post, non_id_actions: [:other_action]]

      params = %{"id" => "1"}

      conn =
        conn(
          %Plug.Conn{
            private: %{phoenix_action: :other_action},
            assigns: %{current_user: %User{id: 1}, authorized: true}
          },
          :get,
          "/posts/other-action",
          params
        )

      expected = Plug.Conn.assign(conn, :authorized, true)

      assert authorize_resource(conn, opts) == expected
    end
  end

  test "it authorizes the controller correctly" do
    opts = [model: Post]

    # when the action is "new"
    params = %{}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :new, phoenix_controller: Myproject.SampleController},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/new",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_controller(conn, opts) == expected

    # when the action is "create"
    params = %{}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :create, phoenix_controller: Myproject.SampleController},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/create",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_controller(conn, opts) == expected

    # when the action is "index"
    params = %{}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :index, phoenix_controller: Myproject.SampleController},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_controller(conn, opts) == expected

    # when the action is a phoenix action
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show, phoenix_controller: Myproject.SampleController},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts/1",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_controller(conn, opts) == expected

    # when the current user can access the given resource
    # and the action and controller are specified in conn.assigns.canary_action
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{},
          assigns: %{
            current_user: %User{id: 1},
            canary_action: :show,
            canary_controller: Myproject.SampleController
          }
        },
        :get,
        "/posts/1",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_controller(conn, opts) == expected

    # when both conn.assigns.canary_action and conn.private.phoenix_action are defined
    # it uses conn.assigns.canary_action for authorization
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_action: :show, phoenix_controller: Myproject.SampleController},
          assigns: %{current_user: %User{id: 1}, canary_action: :unauthorized}
        },
        :get,
        "/posts/1",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, false)

    assert authorize_controller(conn, opts) == expected

    # when the current user cannot access the given action
    params = %{"id" => "2"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_controller: Myproject.SampleController},
          assigns: %{current_user: %User{id: 1}, canary_action: :someaction}
        },
        :get,
        "/posts/2",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, false)

    assert authorize_controller(conn, opts) == expected

    # when current_user is nil
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_controller: Myproject.SampleController},
          assigns: %{current_user: nil, canary_action: :create}
        },
        :post,
        "/posts",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, false)

    assert authorize_controller(conn, opts) == expected

    # when an action is restricted on a controller
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_controller: Myproject.PartialAccessController},
          assigns: %{current_user: %User{id: 1}, canary_action: :new}
        },
        :post,
        "/posts",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, false)

    assert authorize_controller(conn, opts) == expected

    # when an action is authorized on a controller
    params = %{"id" => "1"}

    conn =
      conn(
        %Plug.Conn{
          private: %{phoenix_controller: Myproject.PartialAccessController},
          assigns: %{current_user: %User{id: 1}, canary_action: :show}
        },
        :post,
        "/posts",
        params
      )

    expected = Plug.Conn.assign(conn, :authorized, true)

    assert authorize_controller(conn, opts) == expected
  end
end
