defmodule RnxServerWeb.ClaimGodotTokenPlug do
  import Plug.Conn
  import Phoenix.Controller

  alias RnxServer.Auth

  def init(opts), do: opts

  def call(conn, _opts) do
    # Usamos `with` para buscar el escenario exacto:
    # 1. Hay un "token" en los parámetros de la URL.
    # 2. Ya hay un `current_user` cargado en la sesión del navegador.
    with token_string when not is_nil(token_string) <- conn.query_params["token"],
         %{} = current_user <- conn.assigns[:current_user] do
      
      # Si ambas condiciones se cumplen, ¡este es nuestro caso!
      # Reclamamos el token para el usuario que ya está en la sesión.
      case Auth.get_valid_login_token(token_string) do
        nil ->
          # El token no es válido o expiró, así que no hacemos nada especial.
          conn

        login_token ->
          # El token es válido, lo reclamamos y mostramos la página de éxito.
          Auth.claim_login_token(login_token, current_user)

          conn
          |> put_view(RnxServerWeb.AuthHTML)
          |> render("success.html")
          |> halt() # ¡Importante! Detenemos el resto de la petición.
      end
    else
      # Si falta el token o no hay usuario en sesión, no hacemos nada.
      _ ->
        conn
    end
  end
end