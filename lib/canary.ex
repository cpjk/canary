defmodule Canary do
  defmacro __using__(_) do
    quote do
      import Canada.Can, only: [can?: 3]
      import Canary.Plugs
    end
  end
end
