defmodule RnxServerWeb.Api.AuthController do
  use RnxServerWeb, :controller
  alias RnxServer.Auth
  alias RnxServer.Accounts

  def poll(conn, %{"token" => token_string}) do
    case Auth.get_login_token_for_polling(token_string) do
      # si el token no existe...
      nil ->
        # ... lo creamos
        case Auth.create_login_token(token_string) do
          {:ok, _login_token} ->
            # Y luego respondemos que está pendiente, como si siempre hubiera existido.
            json(conn, %{status: "pending"})
          {:error, _changeset} ->
            # Si hay un error (ej. token duplicado, poco probable), devolvemos error.
            conn
            |> put_status(:internal_server_error)
            |> json(%{status: "error", message: "Could not create token."})
        end

      # si el token ya existe...
      login_token ->
        # ...continuamos con la lógica normal.
        handle_poll_status(conn, login_token)
    end
  end

  defp handle_poll_status(conn, %{user_id: nil}) do
    json(conn, %{status: "pending"})
  end

  defp handle_poll_status(conn, %{user_id: user_id}) do
    user = Accounts.get_user!(user_id)

    # Generate a secure, long-lived token for the game client
    token = Phoenix.Token.sign(conn, "user_token", user.id)

    response_payload = %{
      status: "success",
      session_token: token,
      user: user
    }

    json(conn, response_payload)
  end
end