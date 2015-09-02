defmodule User do
  defstruct id: 1
end

defmodule Post do
  use Ecto.Model

  schema "posts" do
    belongs_to :user, :integer, define_field: false # :defaults not working so define own field with default value

    field :user_id, :integer, default: 1
  end
end

defmodule Repo do
  def get(User, 1), do: %User{}
  def get(User, _id), do: nil

  def get(Post, 1), do: %Post{id: 1}
  def get(Post, 2), do: %Post{id: 2, user_id: 2 }
  def get(Post, _), do: nil

  def all(_), do: [%Post{id: 1}, %Post{id: 2, user_id: 2}]

  def preload(%Post{id: 1}, :user), do: %Post{id: 1}
  def preload(%Post{id: 2, user_id: 2}, :user), do: %Post{id: 2, user_id: 2, user: %User{id: 2}}
  def preload([%Post{id: 1},  %Post{id: 2, user_id: 2}], :user), do: [%Post{id: 1}, %Post{id: 2, user_id: 2, user: %User{id: 2}}]
  def preload(resources, _), do: resources
end

defimpl Canada.Can, for: User do

  def can?(%User{id: user_id}, action, %Post{user_id: user_id})
  when action in [:show], do: true

  def can?(%User{}, :index, Post), do: true

  def can?(%User{}, action, Post)
    when action in [:new, :create], do: true

  def can?(%User{id: user_id}, action, %Post{user: %User{id: user_id}})
    when action in [:edit, :update], do: true

  def can?(%User{}, _, _), do: false
end

defimpl Canada.Can, for: Atom do
  def can?(nil, :create, Post), do: false
end


defmodule PlugTest do
  import Canary.Plugs

  import Plug.Adapters.Test.Conn, only: [conn: 4]

  use ExUnit.Case, async: true

  @moduletag timeout: 100000000

  Application.put_env :canary, :repo, Repo

  test "it loads the resource correctly" do
    opts = [model: Post]

    # when the resource with the id can be fetched
    params = %{"id" => 1}
    conn = conn(%Plug.Conn{private: %{phoenix_action: :show}}, :get, "/posts/1", params)
    expected = %{conn | assigns: Map.put(conn.assigns, :post, %Post{id: 1})}

    assert load_resource(conn, opts) == expected


    # when the resource with the id cannot be fetched
    params = %{"id" => 3}
    conn = conn(%Plug.Conn{private: %{phoenix_action: :show}}, :get, "/posts/3", params)
    expected = %{conn | assigns: Map.put(conn.assigns, :post, nil)}

    assert load_resource(conn, opts) == expected


    # when the action is "index"
    params = %{}
    conn = conn(%Plug.Conn{private: %{phoenix_action: :index}}, :get, "/posts", params)
    expected = %{conn | assigns: Map.put(conn.assigns, :posts, [%Post{id: 1}, %Post{id: 2, user_id: 2}])}

    assert load_resource(conn, opts) == expected


    # when the action is "new"
    params = %{}
    conn = conn(%Plug.Conn{private: %{phoenix_action: :new}}, :get, "/posts/new", params)
    expected = %{conn | assigns: Map.put(conn.assigns, :post, nil)}

    assert load_resource(conn, opts) == expected


    # when the action is "create"
    params = %{}
    conn = conn(%Plug.Conn{private: %{phoenix_action: :create}}, :post, "/posts/create", params)
    expected = %{conn | assigns: Map.put(conn.assigns, :post, nil)}

    assert load_resource(conn, opts) == expected
  end

  test "it authorizes the resource correctly" do
    opts = [model: Post]

    # when the action is "new"
    params = %{}
    conn = conn(
      %Plug.Conn{
        private: %{phoenix_action: :new},
        assigns: %{current_user: %User{id: 1}}
      },
      :get,
      "/posts/new",
      params
    )
    expected = %{conn | assigns: Map.put(conn.assigns, :authorized, true)}

    assert authorize_resource(conn, opts) == expected


    # when the action is "create"
    params = %{}
    conn = conn(
      %Plug.Conn{
        private: %{phoenix_action: :create},
        assigns: %{current_user: %User{id: 1}}
      },
      :get,
      "/posts/create",
      params
    )
    expected = %{conn | assigns: Map.put(conn.assigns, :authorized, true)}

    assert authorize_resource(conn, opts) == expected


    # when the action is "index"
    params = %{}
    conn = conn(
      %Plug.Conn{
        private: %{phoenix_action: :index},
        assigns: %{current_user: %User{id: 1}}
      },
      :get,
      "/posts",
      params
    )
    expected = %{conn | assigns: Map.put(conn.assigns, :authorized, true)}

    assert authorize_resource(conn, opts) == expected


    # when the action is a phoenix action
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


    # when the current user can access the given resource
    # and the action is specified in conn.assigns.action
    params = %{"id" => 1}
    conn = conn(
      %Plug.Conn{
        private: %{},
        assigns: %{current_user: %User{id: 1}, action: :show}
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


    # when the current user cannot access the given resource
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


    # when current_user is nil
    params = %{"id" => 1}
    conn = conn(
      %Plug.Conn{
        private: %{},
        assigns: %{current_user: nil, action: :create}
      },
      :post,
      "/posts",
      params
    )
    expected = %{conn | assigns: Map.put(conn.assigns, :authorized, false)}

    assert authorize_resource(conn, opts) == expected
  end

  test "it loads and authorizes the resource correctly" do
    opts = [model: Post]

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
    expected = %{expected | assigns: Map.put(expected.assigns, :post, %Post{id: 1, user_id: 1})}

    assert load_and_authorize_resource(conn, opts) == expected


    # when the current user cannot access the given resource
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
    expected = %{expected | assigns: Map.put(expected.assigns, :post, nil)}

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
    expected = %{expected | assigns: Map.put(expected.assigns, :post, nil)}

    assert load_and_authorize_resource(conn, opts) == expected
  end


  test "it only loads the resource when the action is in opts[:only]" do
    # when the action is in opts[:only]
    opts = [model: Post, only: :show]
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
    expected = %{conn | assigns: Map.put(conn.assigns, :post, %Post{id: 1})}

    assert load_resource(conn, opts) == expected


    # when the action is not opts[:only]
    opts = [model: Post, only: :other]
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
    expected = conn

    assert load_resource(conn, opts) == expected
  end


  test "it only authorizes actions in opts[:only]" do
    # when the action is in opts[:only]
    opts = [model: Post, only: :show]
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


    # when the action is not opts[:only]
    opts = [model: Post, only: :other]
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
    expected = conn

    assert authorize_resource(conn, opts) == expected
  end


  test "it only loads and authorizes the resource for actions in opts[:only]" do
    # when the action is in opts[:only]
    opts = [model: Post, only: :show]
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
    expected = %{conn | assigns: Map.put(expected.assigns, :post, %Post{id: 1, user_id: 1})}

    assert load_and_authorize_resource(conn, opts) == expected


    # when the action is not opts[:only]
    opts = [model: Post, only: :other]
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
    expected = conn

    assert load_and_authorize_resource(conn, opts) == expected
  end


  test "it skips the plug when both opts[:only] and opts[:except] are specified" do
    # when the plug is load_resource
    opts = [model: Post, only: :show, except: :index]
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
    expected = conn

    assert load_resource(conn, opts) == expected


    # when the plug is authorize_resource
    opts = [model: Post, only: :show, except: :index]
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
    expected = conn

    assert authorize_resource(conn, opts) == expected


    # when the plug is load_and_authorize_resource
    opts = [model: Post, only: :show, except: :index]
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
    expected = conn

    assert load_and_authorize_resource(conn, opts) == expected
  end

  test "it correctly skips authorization for exempt actions" do
    # when the action is exempt
    opts = [model: Post, except: :show]
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
    expected = conn

    assert authorize_resource(conn, opts) == expected


    # when the action is not exempt
    opts = [model: Post]
    expected = %{conn | assigns: Map.put(expected.assigns, :authorized, true)}

    assert authorize_resource(conn, opts) == expected
  end


  test "it correctly skips loading resources for exempt actions" do
    # when the action is exempt
    opts = [model: Post, except: :show]
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
    expected = conn
    assert load_resource(conn, opts) == expected


    # when the action is not exempt
    opts = [model: Post]
    expected = %{conn | assigns: Map.put(expected.assigns, :post, %Post{id: 1, user_id: 1})}
    assert load_resource(conn, opts) == expected
  end


  test "it correctly skips load_and_authorize_resource for exempt actions" do
    # when the action is exempt
    opts = [model: Post, except: :show]
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
    expected = conn
    assert load_and_authorize_resource(conn, opts) == expected


    # when the action is not exempt
    opts = [model: Post]
    expected = %{conn | assigns: Map.put(conn.assigns, :authorized, true)}
    expected = %{expected | assigns: Map.put(expected.assigns, :post, %Post{id: 1, user_id: 1})}
    assert load_and_authorize_resource(conn, opts) == expected
  end


  test "it loads the resource into a key specified by the :as option" do
    opts = [model: Post, as: :some_key]

    # when the resource with the id can be fetched
    params = %{"id" => 1}
    conn = conn(%Plug.Conn{private: %{phoenix_action: :show}}, :get, "/posts/1", params)
    expected = %{conn | assigns: Map.put(conn.assigns, :some_key, %Post{id: 1})}

    assert load_resource(conn, opts) == expected
  end


  test "it authorizes the resource correctly when the :as key is specified" do
    opts = [model: Post, as: :some_key]

    # when the action is "new"
    params = %{}
    conn = conn(
      %Plug.Conn{
        private: %{phoenix_action: :new},
        assigns: %{current_user: %User{id: 1}}
      },
      :get,
      "/posts/new",
      params
    )
    expected = %{conn | assigns: Map.put(conn.assigns, :authorized, true)}

    assert authorize_resource(conn, opts) == expected
    # need to check that it works for authorization as well, and for load_and_authorize_resource
  end


  test "it loads and authorizes the resource correctly when the :as key is specified" do
    opts = [model: Post, as: :some_key]

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
    expected = %{expected | assigns: Map.put(expected.assigns, :some_key, %Post{id: 1, user_id: 1})}

    assert load_and_authorize_resource(conn, opts) == expected
  end


  test "when the :as key is not specified, it loads the resource into a key inferred from the model name" do
    opts = [model: Post]

    # when the resource with the id can be fetched
    params = %{"id" => 1}
    conn = conn(%Plug.Conn{private: %{phoenix_action: :show}}, :get, "/posts/1", params)
    expected = %{conn | assigns: Map.put(conn.assigns, :post, %Post{id: 1})}

    assert load_resource(conn, opts) == expected
  end


  defmodule CurrentUser do
    use ExUnit.Case, async: true

    defmodule ApplicationConfig do
      use ExUnit.Case, async: false
      import Mock

      test_with_mock "it uses the current_user name configured", Application, [:passthrough], [
        get_env: fn(_,_,_)-> :current_admin end
        ] do
        # when the user configured with opts
        opts = [model: Post, except: :show]
        params = %{"id" => 1}
        conn = conn(
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
      params = %{"id" => 1}
      conn = conn(
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
      params = %{"id" => 1}
      conn = conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{user: %User{id: 1}, authorized: true}
        },
        :get,
        "/posts/1",
        params
      )

      assert_raise KeyError, "key :configured_current_user not found in: %{authorized: true, user: %User{id: 1}}", fn->
        authorize_resource(conn, opts)
      end
    end
  end

  defmodule Preload do
    use ExUnit.Case, async: true

    test "it loads the resource correctly when the :preload key is specified" do
      opts = [model: Post, preload: :user]

      # when the resource with the id can be fetched and the association exists
      params = %{"id" => 2}
      conn = conn(%Plug.Conn{private: %{phoenix_action: :show}}, :get, "/posts/1", params)
      expected = %{conn | assigns: Map.put(conn.assigns, :post, %Post{id: 2, user_id: 2, user: %User{id: 2}})}

      assert load_resource(conn, opts) == expected


      # when the resource with the id can be fetched and the association does not exist
      params = %{"id" => 1}
      conn = conn(%Plug.Conn{private: %{phoenix_action: :show}}, :get, "/posts/1", params)
      expected = %{conn | assigns: Map.put(conn.assigns, :post, %Post{id: 1, user_id: 1})}

      assert load_resource(conn, opts) == expected


      # when the resource with the id cannot be fetched
      params = %{"id" => 3}
      conn = conn(%Plug.Conn{private: %{phoenix_action: :show}}, :get, "/posts/3", params)
      expected = %{conn | assigns: Map.put(conn.assigns, :post, nil)}

      assert load_resource(conn, opts) == expected


      # when the action is "index"
      params = %{}
      conn = conn(%Plug.Conn{private: %{phoenix_action: :index}}, :get, "/posts", params)
      expected = %{conn | assigns: Map.put(conn.assigns, :posts, [%Post{id: 1}, %Post{id: 2, user_id: 2, user: %User{id: 2}}])}

      assert load_resource(conn, opts) == expected


      # when the action is "new"
      params = %{}
      conn = conn(%Plug.Conn{private: %{phoenix_action: :new}}, :get, "/posts/new", params)
      expected = %{conn | assigns: Map.put(conn.assigns, :post, nil)}

      assert load_resource(conn, opts) == expected
    end

    test "it authorizes the resource correctly when the :preload key is specified" do
      opts = [model: Post, preload: :user]

      # when the action is "edit"
      params = %{"id" => 2}
      conn = conn(
        %Plug.Conn{
          private: %{phoenix_action: :edit},
          assigns: %{current_user: %User{id: 2}}
        },
        :get,
        "/posts/edit/2",
        params
      )
      expected = %{conn | assigns: Map.put(conn.assigns, :authorized, true)}

      assert authorize_resource(conn, opts) == expected


      # when the action is "index"
      params = %{}
      conn = conn(
        %Plug.Conn{
          private: %{phoenix_action: :index},
          assigns: %{current_user: %User{id: 1}}
        },
        :get,
        "/posts",
        params
      )
      expected = %{conn | assigns: Map.put(conn.assigns, :authorized, true)}

      assert authorize_resource(conn, opts) == expected
    end

    test "it loads and authorizes the resource correctly when the :preload key is specified" do
      opts = [model: Post, preload: :user]

      # when the current user can access the given resource
      # and the resource can be loaded and the association exists
      params = %{"id" => 2}
      conn = conn(
        %Plug.Conn{
          private: %{phoenix_action: :show},
          assigns: %{current_user: %User{id: 2}}
        },
        :get,
        "/posts/2",
        params
      )
      expected = %{conn | assigns: Map.put(conn.assigns, :authorized, true)}
      expected = %{expected | assigns: Map.put(expected.assigns, :post, %Post{id: 2, user_id: 2, user: %User{id: 2}})}

      assert load_and_authorize_resource(conn, opts) == expected


      # when the current user can access the given resource
      # and the resource can be loaded and the association does not exist
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
      expected = %{expected | assigns: Map.put(expected.assigns, :post, %Post{id: 1, user_id: 1})}

      assert load_and_authorize_resource(conn, opts) == expected

      # when the action is "edit"
      params = %{"id" => 2}
      conn = conn(
        %Plug.Conn{
          private: %{phoenix_action: :edit},
          assigns: %{current_user: %User{id: 2}}
        },
        :get,
        "/posts/edit/2",
        params
      )
      expected = %{conn | assigns: Map.put(conn.assigns, :authorized, true)}
      expected = %{expected | assigns: Map.put(expected.assigns, :post, %Post{id: 2, user_id: 2, user: %User{id: 2}})}

      assert load_and_authorize_resource(conn, opts) == expected
    end
  end
end
