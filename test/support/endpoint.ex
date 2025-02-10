defmodule Canary.HooksHelper.Endpoint do
  use Phoenix.Endpoint, otp_app: :canary

  socket "/live", Phoenix.LiveView.Socket

  plug Canary.HooksHelper.Router
end
