if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Canary.Hooks do
    @moduledoc """

    Hooks functions for loading and authorizing resources for the LiveView events.
    If you want to authorize `handle_params` and `handle_event` LiveView callbacks
    you can use `mount_canary` macro to attach the hooks.

    For `handle_params` it uses `socket.assigns.live_action` as `:action`.
    For `handle_event` it uses the event name as `:action`.

    > Note that the `event_name` is a string - but in Canary it's converted to an atom for consistency.

    The main difference beteween `Canary.Hooks` and `Canary.Plugs` is that
    in `Canary.Hooks` there is no `:non_id_actions` option. It won't load all resources
    like it's done with plugs, but you can still use `:authorize_resource`.


    For the authorization actions, when the `:required` is not set (by default it's false) it might be nil.
    Then the `Canada.Can` implementation should be the module name of the model rather than a struct.

    ## Example
      ```elixir
      use Canary.Hooks

      mount_canary :load_and_authorize_resource,
        on: [:handle_params, :handle_event],
        model: Post,
        required: true,
        only: [:show, :edit, :update]

      mount_canary :authorize_resource,
        on: [:handle_event],
        model: Post,
        only: [:my_event]

      # ...

      def handle_params(params, _uri, socket) do
        # resource is already loaded and authorized
        post = socket.assigns.post
      end

      def handle_event("my_event", _unsigned_params, socket) do
        # Only admin is allowed to perform my_event
      end

      ```

      `lib/abilities/user.ex`:

      ```elixir
      defimpl Canada.Can, for: User do

        def can?(%User{} = user, :my_event, Post), do: user.role == "admin"

        def can?(%User{id: id}, _, %Post{user_id: user_id}), do: id == user_id
      end
      ```
    """
    # Copyright 2025 Piotr Baj
    @moduledoc since: "2.0.0"

    import Canary.Utils
    import Canada.Can, only: [can?: 3]
    import Phoenix.LiveView, only: [attach_hook: 4]
    import Phoenix.Component, only: [assign: 3]

    alias Phoenix.LiveView.Socket

    @doc false
    defmacro __using__(_opts) do
      quote do
        import Canary.Hooks

        Module.register_attribute(__MODULE__, :canary_hooks, accumulate: true)

        # Register the Canary.Hooks.__before_compile__/1 callback to be called before Phoenix.LiveView.
        hooks = Module.delete_attribute(__MODULE__, :before_compile)
        @before_compile Canary.Hooks
        Enum.each(hooks, fn {mod, fun} ->
          @before_compile {mod, fun}
        end)
      end
    end

    @doc false
    defmacro __before_compile__(env) do
      stages =
        Module.get_attribute(env.module, :canary_hooks, [])
        |> Enum.reverse()

      wrapped_hooks = Enum.with_index(stages, &wrap_hooks/2)
      mount_attach = attach_hooks_on_mount(env, stages)

      [wrapped_hooks, mount_attach]
    end

    defp wrap_hooks({stage, hook, opts}, id) do
      name = hook_name(stage, hook, id)

      quote do
        def unquote(name)(hook_arg_1, hook_arg_2, %Socket{} = socket) do
          metadata = %{hook: unquote(hook), stage: unquote(stage), opts: unquote(opts)}
          handle_hook(metadata, [hook_arg_1, hook_arg_2, socket])
        end
      end
    end

    defp attach_hooks_on_mount(env, stages) do
      hooks =
        Enum.with_index(stages)
        |> Enum.map(fn {{stage, hook, _opts}, id} ->
          name = hook_name(stage, hook, id)
          {name, stage}
        end)

      quote bind_quoted: [module: env.module, hooks: hooks] do
        on_mount {Canary.Hooks, {:initialize, module, hooks}}
      end
    end

    defp hook_name(stage, hook, id) do
      String.to_atom("#{stage}_#{hook}_#{id}")
    end

    @doc false
    def handle_hook(metadata, [hook_arg_1, hook_arg_2, socket]) do
      %{hook: hook, stage: stage, opts: opts} = metadata

      case hook do
        :load_resource ->
          load_resource(stage, hook_arg_1, hook_arg_2, socket, opts)

        :authorize_resource ->
          authorize_resource(stage, hook_arg_1, hook_arg_2, socket, opts)

        :load_and_authorize_resource ->
          load_and_authorize_resource(stage, hook_arg_1, hook_arg_2, socket, opts)

        _ ->
          IO.warn(
            "Invalid type #{inspect(hook)} for Canary hook call. Please review defined hooks with mount_canary/2.",
            module: __MODULE__
          )

          {:cont, socket}
      end
    end

    @doc """
    Mount canary authorization hooks on the current module.
    It creates a wrapper function to handle_params and handle_event,
    and attaches the hooks to the Live View.

    ## Example
      ```
      mount_canary :load_and_authorize_resource,
        model: Post,
        required: true,
        only: [:edit: :update]
      ```
    """
    defmacro mount_canary(type, opts) do
      stages = get_stages(opts)

      if Enum.empty?(stages),
        do:
          IO.warn("mount_canary called with empty :on stages",
            module: __CALLER__.module,
            file: __CALLER__.file,
            line: __CALLER__.line
          )

      Enum.reduce(stages, [], fn stage, acc ->
        [put_canary_hook(__CALLER__.module, stage, type, opts) | acc]
      end)
      |> Enum.reverse()
    end

    defp put_canary_hook(module, stage, type, opts) do
      quote do
        Module.put_attribute(
          unquote(module),
          :canary_hooks,
          {unquote(stage), unquote(type), unquote(opts)}
        )
      end
    end

    @doc false
    def on_mount({:initialize, mod, stages}, _params, _session, %Socket{} = socket) do
      socket =
        Enum.reduce(stages, socket, fn {name, stage}, socket ->
          fun = Function.capture(mod, name, 3)
          attach_hook(socket, name, stage, fun)
        end)

      {:cont, socket}
    end

    def on_mount(_, :not_mounted_at_router, _session, socket), do: {:cont, socket}

    @doc """
    Authorize the `:current_user` for the ginve resource. If the `:current_user` is not authorized it will halt the socket.

    For the authorization check, it uses the `can?/3` function from the `Canada.Can` module -

    `can?(subject, action, resource)` where:

    1. The subject is the `:current_user` from the socket assigns. The `:current_user` key can be changed in the `opts` or in the `Application.get_env(:canary, :current_user, :current_user)`. By default it's `:current_user`.
    2. The action for `handle_params` is `socket.assigns.live_action`, for `handle_event` it uses the event name.
    3. The resource is the loaded resource from the socket assigns or the model name if the resource is not loaded and not required.

    Required opts:

    * `:model` - Specifies the module name of the model to load resources from
    * `:on` - Specifies the LiveView lifecycle stages to attach the hook. Default :handle_params

    Optional opts:

    * `:only` - Specifies which actions to authorize
    * `:except` - Specifies which actions for which to skip authorization
    >  For `handle_params` it uses `socket.assigns.live_action` as `:action`.
    >  For `handle_event` it uses the event name as `:action`.

    * `:as` - Specifies the `resource_name` to get from assigns
    * `:current_user` - Specifies the key in the socket assigns to get the current user
    * `:required` - Specifies if the resource is required, when it's not assigned in socket it will halt the socket
    * `:unauthorized_handler` - Specify a handler function to be called if the action is unauthorized

    Example:

    ```elixir

    mount_canary :authorize_resource,
      model: Post,
      only: [:show, :edit, :update]
      current_user: :current_user

    mount_canary :authorize_resource,
      model: Post,
      as: :custom_resource_name,
      except: [:new, :create],
      unauthorized_handler: {ErrorHandler, :unauthorized_handler}

    ```
    """
    def authorize_resource(:handle_params, _params, _uri, %Socket{} = socket, opts) do
      action = socket.assigns.live_action
      do_authorize_resource(action, socket, opts)
    end

    def authorize_resource(:handle_event, event_name, _unsigned_params, %Socket{} = socket, opts) do
      action = String.to_atom(event_name)
      do_authorize_resource(action, socket, opts)
    end

    @doc """
    Loads the resource and assigns it to the socket. When resource is required it will
    halt the socket if the resource is not found.

    `load_resource` wrapper for attached hook functions, similar to the `load_resource/2` plug
    but for LiveView events on `:handle_params` and `:handle_event` stages.

    Required opts:

    * `:model` - Specifies the module name of the model to load resources from
    * `:on` - Specifies the LiveView lifecycle stages to attach the hook. Default :handle_params

    Optional opts:
    * `:only` - Specifies which actions to authorize
    * `:except` - Specifies which actions for which to skip authorization
    >  For `handle_params` it uses `socket.assigns.live_action` as `:action`.
    >  For `handle_event` it uses the event name as `:action`.

    * `:as` - Specifies the `resource_name` to use in assigns
    * `:preload` - Specifies association(s) to preload
    * `:id_name` - Specifies the name of the id in `params`, defaults to "id"
    * `:id_field` - Specifies the name of the ID field in the database for searching :id_name value, defaults to "id".
    * `:required` - Specifies if the resource is required, when it's not found it will halt the socket
    * `:not_found_handler` - Specify a handler function to be called if the resource is not found

    Example:

    ```elixir

    mount_canary :load_resource,
      model: Post,
      only: [:show, :edit, :update],
      preload: [:comments]

    mount_canary :load_resource,
      on: [:handle_params, :handle_event]
      model: Post,
      as: :custom_name,
      except: [:new, :create],
      preload: [:comments],
      required: true,
      not_found_handler: {ErrorHandler, :not_found_handler}

    ```
    """
    def load_resource(:handle_params, params, _uri, %Socket{} = socket, opts) do
      action = socket.assigns.live_action
      do_load_resource(action, socket, params, opts)
    end

    def load_resource(:handle_event, event_name, unsigned_params, %Socket{} = socket, opts) do
      action = String.to_atom(event_name)
      do_load_resource(action, socket, unsigned_params, opts)
    end

    @doc """
    Loads and autorize resource and assigns it to the socket. When resource is required it will
    halt the socket if the resource is not found. If the user is not authorized it will halt the socket.

    It combines `load_resource` and `authorize_resource` functions.

    Required opts:

    * `:model` - Specifies the module name of the model to load resources from
    * `:on` - Specifies the LiveView lifecycle stages to attach the hook. Default :handle_params

    Optional opts:
    * `:only` - Specifies which actions to authorize
    * `:except` - Specifies which actions for which to skip authorization
    >  For `handle_params` it uses `socket.assigns.live_action` as `:action`.
    >  For `handle_event` it uses the event name as `:action`.

    * `:as` - Specifies the `resource_name` to use in assigns
    * `:current_user` - Specifies the key in the socket assigns to get the current user
    * `:preload` - Specifies association(s) to preload
    * `:id_name` - Specifies the name of the id in `params`, defaults to "id"
    * `:id_field` - Specifies the name of the ID field in the database for searching :id_name value, defaults to "id".
    * `:required` - Specifies if the resource is required, when it's not found it will halt the socket
    * `:not_found_handler` - Specify a handler function to be called if the resource is not found
    * `:unauthorized_handler` - Specify a handler function to be called if the action is unauthorized

    Example:

    ```elixir

    mount_canary :load_and_authorize_resource,
      model: Comments,
      id_name: :post_id,
      id_field: :post_id,
      required: true,
      only: [:comments]

    mount_canary :load_and_authorize_resource,
      model: Post,
      as: :custom_name,
      except: [:new, :create],
      preload: [:comments],
      required: true,
      error_handler: CustomErrorHandler
    ```

    """
    def load_and_authorize_resource(:handle_params, params, _uri, %Socket{} = socket, opts) do
      action = socket.assigns.live_action
      do_load_and_authorize_resource(action, params, socket, opts)
    end

    def load_and_authorize_resource(
          :handle_event,
          event_name,
          unsigned_params,
          %Socket{} = socket,
          opts
        ) do
      action = String.to_atom(event_name)
      do_load_and_authorize_resource(action, unsigned_params, socket, opts)
    end

    defp do_load_resource(action, socket, params, opts) do
      if action_valid?(action, opts) do
        load_resource(socket, params, opts)
        |> verify_resource(opts)
      else
        {:cont, socket}
      end
    end

    defp do_load_and_authorize_resource(action, params, socket, opts) do
      if action_valid?(action, opts) do
        load_resource(socket, params, opts)
        |> check_authorization(action, opts)
        |> verify_authorized_resource(opts)
      else
        {:cont, socket}
      end
    end

    defp do_authorize_resource(action, socket, opts) do
      if action_valid?(action, opts) do
        check_authorization(socket, action, opts)
        |> verify_authorized_resource(opts)
      else
        {:cont, socket}
      end
    end

    # Check if the resource is already loaded in the socket assigns
    # If not we need to load and assign it
    defp load_resource(%Socket{} = socket, params, opts) do
      resource =
        case fetch_resource(socket, opts) do
          {:ok, resource} ->
            resource

          _ ->
            repo_get_resource(params, opts)
        end

      assign(socket, get_resource_name(opts), resource)
    end

    # Fetch the resource from the socket assigns or nil
    defp fetch_resource(%Socket{} = socket, opts) do
      case Map.get(socket.assigns, get_resource_name(opts), nil) do
        resource when is_struct(resource) ->
          if resource.__struct__ == opts[:model] do
            {:ok, resource}
          else
            nil
          end

        _ ->
          nil
      end
    end

    # Load the resource from the repo
    defp repo_get_resource(params, opts) do
      repo = Application.get_env(:canary, :repo)
      field_name = Keyword.get(opts, :id_field, "id")
      get_map_args = %{String.to_atom(field_name) => get_resource_id(params, opts)}

      repo.get_by(opts[:model], get_map_args)
      |> preload_if_needed(repo, opts)
    end

    # Perform the authorization check
    defp check_authorization(%Socket{} = socket, action, opts) do
      current_user_name =
        opts[:current_user] || Application.get_env(:canary, :current_user, :current_user)

      current_user = Map.fetch(socket.assigns, current_user_name)
      resource = fetch_resoruce_or_model(socket, opts)

      case {current_user, resource} do
        {{:ok, _current_user}, nil} ->
          assign(socket, :authorized, false)
        {{:ok, current_user}, _} ->
          assign(socket, :authorized, can?(current_user, action, resource))
        _ ->
          assign(socket, :authorized, false)
      end
    end

    # Fetch resource form assigns or model name if empty and not required
    defp fetch_resoruce_or_model(%Socket{} = socket, opts) do
      case fetch_resource(socket, opts) do
        {:ok, resource} ->
          resource

        _ ->
          if required?(opts) do
            nil
          else
            opts[:model]
          end
      end
    end

    # Verify if subject is authorized to perform action on resource
    defp verify_authorized_resource(%Socket{} = socket, opts) do
      authorized = Map.get(socket.assigns, :authorized, false)

      if authorized do
        verify_resource(socket, opts)
      else
        apply_error_handler(socket, :unauthorized_handler, opts)
      end
    end

    # Verify if the resource is loaded and if it is required
    defp verify_resource(%Socket{} = socket, opts) do
      is_required = required?(opts)
      resource = fetch_resource(socket, opts)

      if is_nil(resource) && is_required do
        apply_error_handler(socket, :not_found_handler, opts)
      else
        {:cont, socket}
      end
    end

    defp get_resource_name(opts) do
      case opts[:as] do
        nil ->
          opts[:model]
          |> Module.split()
          |> List.last()
          |> Macro.underscore()
          |> String.to_atom()

        as ->
          as
      end
    end

    defp get_stages(opts) do
      Keyword.get(opts, :on, :handle_params)
      |> validate_stages()
    end

    defp validate_stages(stage) when is_atom(stage), do: validate_stages([stage])

    defp validate_stages(stages) when is_list(stages) do
      allowed_satges = [:handle_params, :handle_event]
      Enum.filter(stages, &Enum.member?(allowed_satges, &1))
    end
  end
end
