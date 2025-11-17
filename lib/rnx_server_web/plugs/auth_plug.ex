defmodule RnxServerWeb.AuthPlug do
  import Plug.Conn
  import Phoenix.Controller

  alias RnxServer.Accounts
  # alias RnxServerWeb.UserSocket

  def init(opts), do: opts

  # Definimos aquí el mismo max_age que en UserSocket para consistencia.
  @max_age 2_592_000 # 30 días en segundos

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         # Usamos el @max_age definido en este módulo, previene errores en cadena.
         {:ok, user_id} <- Phoenix.Token.verify(conn, "user_token", token, max_age: @max_age),
         user <- Accounts.get_user!(user_id) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Unauthorized"})
        |> halt()
    end
  end
end