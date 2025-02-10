defmodule Canary.HooksTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Canary.HooksHelper.{PageLive, PostLive}
  @endpoint Canary.HooksHelper.Endpoint

  setup_all do
    Application.put_env(:canary, Canary.HooksHelper.Endpoint,
      live_view: [signing_salt: "eTh8jeshoe2Bie4e"],
      secret_key_base: String.duplicate("57689", 50)
    )

    Application.put_env(:canary, :repo, Repo)

    start_supervised!(Canary.HooksHelper.Endpoint)
    |> Process.link()

    conn =
      Plug.Test.init_test_session(build_conn(), %{})
      |> Plug.Conn.assign(:current_user, %User{id: 1})

    {:ok, conn: conn}
  end

  describe "handle_hook/2" do
    test "load_resource hook on handle_params loads resource when is available" do
      uri = "http://localhost/post"
      metadata = %{hook: :load_resource, stage: :handle_params, opts: [model: Post]}
      params = %{}

      assert {:cont, socket} =
               Canary.Hooks.handle_hook(metadata, [params, uri, build_socket()])

      assert socket.assigns.post == nil

      params = %{"id" => "1"}

      assert {:cont, socket} =
               Canary.Hooks.handle_hook(metadata, [params, uri, build_socket()])

      assert socket.assigns.post == %Post{id: 1}
    end

    test "load_resource accepts already assigned resource when it matches" do
      uri = "http://localhost/post"
      metadata = %{hook: :load_resource, stage: :handle_params, opts: [model: Post]}
      params = %{"id" => "2"}

      socket =
        build_socket()
        |> put_assigns(%{post: %Post{id: 2}})

      assert {:cont, socket} =
               Canary.Hooks.handle_hook(metadata, [params, uri, socket])

      assert socket.assigns.post == %Post{id: 2}

      socket =
        build_socket()
        |> put_assigns(%{post: %User{id: 1}})

      assert {:cont, socket} =
               Canary.Hooks.handle_hook(metadata, [params, uri, socket])

      assert socket.assigns.post == %Post{id: 2, user_id: 2}
    end

    test "load_resource hook on handle_params assigns nil when resource is not available" do
      uri = "http://localhost/post"
      params = %{"id" => "13"}

      metadata = %{
        hook: :load_resource,
        stage: :handle_params,
        opts: [model: Post, required: true]
      }

      assert {:halt, socket} =
               Canary.Hooks.handle_hook(metadata, [params, uri, build_socket()])

      assert socket.assigns.post == nil
    end

    test "load_resource hook on handle_event" do
      metadata = %{
        hook: :load_resource,
        stage: :handle_event,
        opts: [model: Post, required: true]
      }

      params = %{"id" => "1"}

      assert {:cont, socket} =
               Canary.Hooks.handle_hook(metadata, ["my_event", params, build_socket()])

      assert socket.assigns.post == %Post{id: 1}

      params = %{"id" => "13"}

      assert {:halt, socket} =
               Canary.Hooks.handle_hook(metadata, ["my_event", params, build_socket()])

      assert socket.assigns.post == nil
    end

    test "authorize_resource hook on handle_params" do
      uri = "http://localhost/post"
      metadata = %{hook: :authorize_resource, stage: :handle_params, opts: [model: Post]}
      params = %{}

      socket =
        build_socket()
        |> put_assigns(%{post: %Post{id: 1}, current_user: %User{id: 1}})

      assert {:cont, socket} =
               Canary.Hooks.handle_hook(metadata, [params, uri, socket])

      assert socket.assigns.authorized == true

      socket =
        build_socket(:delete)
        |> put_assigns(%{post: %Post{id: 1}, current_user: %User{id: 1}})

      assert {:halt, socket} =
               Canary.Hooks.handle_hook(metadata, [params, uri, socket])

      assert socket.assigns.authorized == false

      socket =
        build_socket(:create)
        |> put_assigns(%{current_user: %User{id: 1}})

      assert {:cont, socket} =
               Canary.Hooks.handle_hook(metadata, [params, uri, socket])

      assert socket.assigns.authorized == true
    end

    test "authorize_resource hook on handle_event" do
      metadata = %{hook: :authorize_resource, stage: :handle_event, opts: [model: Post]}
      params = %{}

      socket =
        build_socket()
        |> put_assigns(%{post: %Post{id: 1}, current_user: %User{id: 1}})

      assert {:cont, socket} =
               Canary.Hooks.handle_hook(metadata, ["create", params, socket])

      assert socket.assigns.authorized == true

      socket =
        build_socket(:delete)
        |> put_assigns(%{post: %Post{id: 1}, current_user: %User{id: 1}})

      assert {:halt, socket} =
               Canary.Hooks.handle_hook(metadata, ["delete", params, socket])

      assert socket.assigns.authorized == false
    end

    test "load_and_authorize_resource on handle_params" do
      uri = "http://localhost/post"

      metadata = %{
        hook: :load_and_authorize_resource,
        stage: :handle_params,
        opts: [model: Post, required: true, preload: :user]
      }

      params = %{"id" => "1"}

      socket =
        build_socket(:edit)
        |> put_assigns(%{current_user: %User{id: 1}})

      assert {:cont, socket} =
               Canary.Hooks.handle_hook(metadata, [params, uri, socket])

      assert socket.assigns.post == %Post{id: 1} |> Repo.preload(:user)
      assert socket.assigns.authorized == true

      socket =
        build_socket()
        |> put_assigns(%{current_user: %User{id: 1}})

      params = %{"id" => "13"}

      assert {:halt, socket} =
               Canary.Hooks.handle_hook(metadata, [params, uri, socket])

      assert socket.assigns.post == nil
      assert socket.assigns.authorized == false
    end

    test "load_and_authorize_resource on handle_event" do
      metadata = %{
        hook: :load_and_authorize_resource,
        stage: :handle_event,
        opts: [model: Post, required: true, preload: :user]
      }

      params = %{"id" => "1"}

      socket =
        build_socket()
        |> put_assigns(%{current_user: %User{id: 1}})

      assert {:cont, socket} =
               Canary.Hooks.handle_hook(metadata, ["edit", params, socket])

      assert socket.assigns.post == %Post{id: 1} |> Repo.preload(:user)
      assert socket.assigns.authorized == true

      socket =
        build_socket()
        |> put_assigns(%{current_user: %User{id: 1}})

      params = %{"id" => "13"}

      assert {:halt, socket} =
               Canary.Hooks.handle_hook(metadata, ["update", params, socket])

      assert socket.assigns.post == nil
      assert socket.assigns.authorized == false
    end

    test "accepts :id_field to override the default id field" do
      uri = "http://localhost/post"
      metadata = %{hook: :load_resource, stage: :handle_params, opts: [model: Post, id_field: "slug"]}
      params = %{"id" => "slug1"}

      assert {:cont, socket} =
               Canary.Hooks.handle_hook(metadata, [params, uri, build_socket()])

      assert socket.assigns.post == %Post{id: 1, slug: "slug1"}

      metadata = %{hook: :load_resource, stage: :handle_params, opts: [model: Post]}
      params = %{"id" => "1"}

      assert {:cont, socket} =
               Canary.Hooks.handle_hook(metadata, [params, uri, build_socket()])

      assert socket.assigns.post == %Post{id: 1}
    end

    test "accepts :id_name to override the default id field" do
      uri = "http://localhost/post"
      metadata = %{hook: :load_resource, stage: :handle_params, opts: [model: Post, id_name: "blog_post_id"]}
      params = %{"blog_post_id" => "2"}

      assert {:cont, socket} =
               Canary.Hooks.handle_hook(metadata, [params, uri, build_socket()])

      assert socket.assigns.post == Repo.get(Post, 2)

      params = %{"id" => "1"}
      assert {:cont, socket} =
               Canary.Hooks.handle_hook(metadata, [params, uri, build_socket()])

      assert socket.assigns.post == nil
    end


    test "accepts :preload to preload the resource" do
      uri = "http://localhost/post"
      metadata = %{hook: :load_resource, stage: :handle_params, opts: [model: Post, preload: :user]}
      params = %{"id" => "1"}

      assert {:cont, socket} =
               Canary.Hooks.handle_hook(metadata, [params, uri, build_socket()])

      assert socket.assigns.post == %Post{id: 1} |> Repo.preload(:user)

      metadata = %{hook: :load_resource, stage: :handle_params, opts: [model: Post]}
      params = %{"id" => "1"}

      assert {:cont, socket} =
               Canary.Hooks.handle_hook(metadata, [params, uri, build_socket()])

      assert socket.assigns.post != %Post{id: 1} |> Repo.preload(:user)

    end

    test "accepts :as to override the default assign name" do
      uri = "http://localhost/post"
      metadata = %{hook: :load_resource, stage: :handle_params, opts: [model: Post, as: :my_post]}
      params = %{"id" => "1"}

      assert {:cont, socket} =
               Canary.Hooks.handle_hook(metadata, [params, uri, build_socket()])

      assert socket.assigns.my_post == %Post{id: 1}
    end

    test "accepts :current_user to override the default subject assign name" do
      uri = "http://localhost/post"

      metadata = %{
        hook: :authorize_resource,
        stage: :handle_params,
        opts: [model: Post, current_user: :my_user]
      }

      params = %{}

      socket =
        build_socket()
        |> put_assigns(%{post: %Post{id: 1}, current_user: %User{id: 1}})

      assert {:halt, socket} =
               Canary.Hooks.handle_hook(metadata, [params, uri, socket])

      assert socket.assigns.authorized == false
    end

    test "emits a warning when the hook is not defined" do
      metadata = %{hook: :invalid_hook, stage: :handle_params, opts: [model: Post]}

      assert ExUnit.CaptureIO.capture_io(:stderr, fn ->
               {:cont, socket} =
                 Canary.Hooks.handle_hook(metadata, [%{}, "http://localhost/post", build_socket()])

               assert_raise KeyError, ~r/key :post not found in/, fn ->
                 Map.fetch!(socket.assigns, :post)
               end
             end) =~
               "Invalid type :invalid_hook for Canary hook call. Please review defined hooks with mount_canary/2"
    end
  end

  describe "integration for :load_resource" do
    test "it loads the resource correctly", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/post/1")
      assert %{post: %Post{id: 1}} = PostLive.fetch_assigns(lv)

      {:ok, lv, _html} = live(conn, "/post/13")
      assert %{post: nil} = PostLive.fetch_assigns(lv)
    end

    test "it halt the socket when the resource is required", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/post/13/edit")
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/post/15/update")
    end
  end

  describe "integration for on_mount/4" do
    test "it attaches defined hooks to the socket", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/page")

      {:ok, lifecycle} = PageLive.fetch_lifecycle(lv)

      expected_handle_params = [
        %{
          id: :handle_params_load_resource_0,
          function: &PageLive.handle_params_load_resource_0/3,
          stage: :handle_params
        },
        %{
          id: :handle_params_load_and_authorize_resource_1,
          function: &PageLive.handle_params_load_and_authorize_resource_1/3,
          stage: :handle_params
        }
      ]

      assert Enum.all?(expected_handle_params, &(&1 in lifecycle.handle_params)),
             "Expected Enum: #{inspect(lifecycle.handle_params)} \n to include: #{inspect(expected_handle_params)}"

      expected_handle_events = [
        %{
          id: :handle_event_load_and_authorize_resource_2,
          function: &PageLive.handle_event_load_and_authorize_resource_2/3,
          stage: :handle_event
        }
      ]

      assert Enum.all?(expected_handle_events, &(&1 in lifecycle.handle_event)),
             "Expected Enum: #{inspect(lifecycle.handle_event)} \n to include: #{inspect(expected_handle_events)}"
    end
  end

  describe "mount_canary/2" do
    defmodule TestLive do
      use Phoenix.LiveView
      use Canary.Hooks

      mount_canary(:load_resource,
        model: Post
      )

      mount_canary(:load_and_authorize_resource,
        on: [:handle_params, :handle_event],
        model: User,
        only: [:show]
      )

      def render(assigns) do
        ~H"""
        <div>Test</div>
        """
      end

      def mount(_params, _session, socket) do
        {:ok, socket}
      end
    end

    test "defines wrapper function for events" do
      expected_fun = [
        {:handle_params_load_resource_0, 3},
        {:handle_params_load_and_authorize_resource_1, 3},
        {:handle_event_load_and_authorize_resource_2, 3}
      ]

      assert Enum.all?(expected_fun, &(&1 in TestLive.__info__(:functions)))
    end

    test "adds on_mount hook for attaching event hooks" do
      %{lifecycle: %{mount: mount}} = TestLive.__live__()

      expected_mount = %{
        function: &Canary.Hooks.on_mount/4,
        id:
          {Canary.Hooks,
           {:initialize, TestLive,
            [
              handle_params_load_resource_0: :handle_params,
              handle_params_load_and_authorize_resource_1: :handle_params,
              handle_event_load_and_authorize_resource_2: :handle_event
            ]}},
        stage: :mount
      }

      assert Enum.any?(mount, &(&1 == expected_mount))
    end

    test "emits a warning when no valid stage is provided" do
      assert ExUnit.CaptureIO.capture_io(:stderr, fn ->
               defmodule InvalidLive do
                 use Phoenix.LiveView
                 use Canary.Hooks

                 mount_canary(:load_resource,
                   model: Post,
                   on: [:invalid_stage]
                 )

                 def mount(_params, _session, socket) do
                   {:ok, socket}
                 end
               end
             end) =~
               "mount_canary called with empty :on stages"
    end
  end

  defp build_socket(action \\ :show) do
    %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, live_action: action}}
  end

  defp put_assigns(socket, assigns) do
    %{socket | assigns: Map.merge(socket.assigns, assigns)}
  end
end
