ExUnit.start()


defmodule User do
  defstruct id: 1
end

defmodule Post do
  use Ecto.Schema

  schema "posts" do
    # :defaults not working so define own field with default value
    belongs_to(:user, :integer, define_field: false)

    field(:user_id, :integer, default: 1)
    field(:slug, :string)
  end
end

defmodule Repo do
  def get(User, 1), do: %User{}
  def get(User, _id), do: nil

  def get(Post, 1), do: %Post{id: 1}
  def get(Post, 2), do: %Post{id: 2, user_id: 2}
  def get(Post, _), do: nil

  def all(_), do: [%Post{id: 1}, %Post{id: 2, user_id: 2}]

  def preload(%Post{id: post_id, user_id: user_id}, :user) do
    %Post{id: post_id, user_id: user_id, user: %User{id: user_id}}
  end
  #def preload(%Post{id: 2, user_id: 2}, :user), do: %Post{id: 2, user_id: 2, user: %User{id: 2}}

  def preload([%Post{id: 1}, %Post{id: 2, user_id: 2}], :user),
    do: [%Post{id: 1}, %Post{id: 2, user_id: 2, user: %User{id: 2}}]

  def preload(resources, _), do: resources

  def get_by(User, %{id: "1"}), do: %User{}
  def get_by(User, _), do: nil

  def get_by(Post, %{id: "1"}), do: %Post{id: 1}
  def get_by(Post, %{id: "2"}), do: %Post{id: 2, user_id: 2}
  def get_by(Post, %{id: _}), do: nil

  def get_by(Post, %{slug: "slug1"}), do: %Post{id: 1, slug: "slug1"}
  def get_by(Post, %{slug: "slug2"}), do: %Post{id: 2, slug: "slug2", user_id: 2}
  def get_by(Post, %{slug: _}), do: nil
end

defimpl Canada.Can, for: User do
  def can?(%User{}, action, Myproject.PartialAccessController)
      when action in [:index, :show],
      do: true

  def can?(%User{}, action, Myproject.PartialAccessController)
      when action in [:new, :create, :update, :delete],
      do: false

  def can?(%User{}, :index, Myproject.SampleController), do: true

  def can?(%User{id: _user_id}, action, Myproject.SampleController)
      when action in [:index, :show, :new, :create, :update, :delete],
      do: true

  def can?(%User{id: user_id}, action, %Post{user_id: user_id})
      when action in [:index, :show, :new, :create],
      do: true

  def can?(%User{}, :index, Post), do: true

  def can?(%User{}, action, Post)
      when action in [:new, :create, :other_action],
      do: true

  def can?(%User{id: user_id}, action, %Post{user: %User{id: user_id}})
      when action in [:edit, :update],
      do: true

  def can?(%User{}, _, _), do: false
end

defimpl Canada.Can, for: Atom do
  def can?(nil, :create, Post), do: false
  def can?(nil, :create, Myproject.SampleController), do: false
end

defmodule Helpers do
  def unauthorized_handler(conn) do
    conn
    |> Plug.Conn.resp(403, "I'm sorry Dave. I'm afraid I can't do that.")
    |> Plug.Conn.send_resp()
  end

  def not_found_handler(conn) do
    conn
    |> Map.put(:not_found_handler_called, true)
    |> Plug.Conn.resp(404, "Resource not found.")
    |> Plug.Conn.send_resp()
  end

  def non_halting_unauthorized_handler(conn) do
    conn
  end
end

defmodule ErrorHandler do
  @behaviour Canary.ErrorHandler

  def not_found_handler(%Plug.Conn{} = conn) do
    Helpers.not_found_handler(conn)
  end

  def not_found_handler(%Phoenix.LiveView.Socket{} = socket) do
    {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
  end

  def unauthorized_handler(%Plug.Conn{} = conn) do
    Helpers.unauthorized_handler(conn)
  end

  def unauthorized_handler(%Phoenix.LiveView.Socket{} = socket) do
    {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
  end
end
