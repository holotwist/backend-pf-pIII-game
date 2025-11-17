defmodule RnxServerWeb.RedirectIfLoggedInPlug do
  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns.current_user && !Map.has_key?(conn.params, "token") do
      redirect(conn, to: "/users/#{conn.assigns.current_user.id}")
      |> halt()
    else
      conn
    end
  end
end