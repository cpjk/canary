defmodule Canary.Utils do
  @moduledoc """
  Common utils functions for `Canary.Plugs` and `Canary.Hooks`
  """

  @doc """
  Get the resource id from the connection params

      iex> Canary.Utils.get_resource_id(%{"id" => "9"}, [])
      "9"

      iex> Canary.Utils.get_resource_id(%Plug.Conn{params: %{"custom_id" => "1"}}, id_name: "custom_id")
      "1"

      iex> Canary.Utils.get_resource_id(%{"user_id" => "7"}, id_name: "user_id")
      "7"

      iex> Canary.Utils.get_resource_id(%{"other_id" => "9"}, id_name: "id")
      nil
  """
  @moduledoc since: "2.0.0"

  @spec get_resource_id(Plug.Conn.t(), Keyword.t()) :: String.t() | nil
  def get_resource_id(%Plug.Conn{params: params}, opts) do
    get_resource_id(params, opts)
  end

  @spec get_resource_id(map(), Keyword.t()) :: String.t() | nil
  def get_resource_id(params, opts) when is_map(params) do
    case opts[:id_name] do
      nil ->
        params["id"]

      id_name ->
        params[id_name]
    end
  end

  @doc """
  Preload associations if needed
  """
  @spec preload_if_needed(nil, Ecto.Repo.t(), Keyword.t()) :: nil
  def preload_if_needed(nil, _repo, _opts), do: nil

  @spec preload_if_needed([Ecto.Schema.t()], Ecto.Repo.t(), Keyword.t()) :: [Ecto.Schema.t()]
  def preload_if_needed(records, repo, opts) do
    case opts[:preload] do
      nil ->
        records

      models ->
        repo.preload(records, models)
    end
  end

  @doc ~S"""
  Check if an action is valid based on the options.

      iex> Canary.Utils.action_valid?(:index, only: [:index, :show])
        true

      iex> Canary.Utils.action_valid?(:index, except: :index)
        false

      iex> Canary.Utils.action_valid?(:show, except: :index, only: :show)
        ** (ArgumentError) You can't use both :except and :only options
  """
  @spec action_valid?(atom, Keyword.t()) :: boolean
  def action_valid?(action, opts) do
    cond do
      Keyword.has_key?(opts, :except) && Keyword.has_key?(opts, :only) ->
        raise ArgumentError, "You can't use both :except and :only options"

      Keyword.has_key?(opts, :except) ->
        !action_exempt?(action, opts)

      Keyword.has_key?(opts, :only) ->
        action_included?(action, opts)

      true ->
        true
    end
  end

  defp action_exempt?(action, opts) do
    if is_list(opts[:except]) && action in opts[:except] do
      true
    else
      action == opts[:except]
    end
  end

  defp action_included?(action, opts) do
    if is_list(opts[:only]) && action in opts[:only] do
      true
    else
      action == opts[:only]
    end
  end

  @doc """
  Check if a key is present in a keyword list
  """
  @spec required?(Keyword.t()) :: boolean
  def required?(opts) do
    !!Keyword.get(opts, :required, false)
  end

  @doc """
  Apply the error handler to the connection or socket
  """
  @spec apply_error_handler(Plug.Conn.t() , atom, Keyword.t()) :: Plug.Conn.t()
  @spec apply_error_handler(Phoenix.LiveView.Socket.t() , atom, Keyword.t()) :: {:halt, Phoenix.LiveView.Socket.t()}
  def apply_error_handler(conn_or_socket, handler_key, opts) do
    get_handler(handler_key, opts)
    |> apply([conn_or_socket])
  end

  defp get_handler(handler_key, opts) do
    mod_or_mod_fun =
      Keyword.get(opts, handler_key) ||
        Application.get_env(:canary, :error_handler, Canary.DefaultHandler)

    case mod_or_mod_fun do
      {mod, fun} ->
        Function.capture(mod, fun, 1)

      mod when is_atom(mod) ->
        Function.capture(mod, handler_key, 1)

      _ ->
        raise ArgumentError, "
            Invalid error handler, expected a module or a tuple with a module and a function,
            got: #{inspect(mod_or_mod_fun)}"
    end
  end

end
