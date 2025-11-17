defmodule RnxServer.Repo do
  use Ecto.Repo,
    otp_app: :rnx_server,
    adapter: Ecto.Adapters.Postgres
end
