defmodule RnxServerWeb.AuthPlugWeb do
  import Plug.Conn
  import Phoenix.Controller

  alias RnxServer.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    if user_id do
      user = Accounts.get_user!(user_id)
      assign(conn, :current_user, user)
    else
      conn
      |> put_flash(:error, "Debes iniciar sesión para acceder a esta página.")
      |> redirect(to: "/auth/login")
      |> halt()
    end
  end
end