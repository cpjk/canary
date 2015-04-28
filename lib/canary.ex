defmodule Canary do
  defmacro __using__(_) do
    quote do
      import Canary.Plugs
    end
  end
end
