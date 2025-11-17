defmodule RnxServerWeb.AuthController do
  use RnxServerWeb, :controller
  alias RnxServer.Auth
  alias RnxServer.Accounts
  alias RnxServer.Accounts.User

  def new(conn, params) do
    # Si hay un usuario en sesión Y NO es el flujo de Godot, redirigir.
    if conn.assigns.current_user && !params["token"] do
      redirect(conn, to: "/users/#{conn.assigns.current_user.id}")
    else
      # Si no, mostrar la página de login con el token.
      changeset = Accounts.change_user(%User{})
      render(conn, "new.html", changeset: changeset, token: Map.get(params, "token"))
    end
  end

  def create(conn, %{"_csrf_token" => _csrf, "user" => user_params} = params) do
    require Logger
    Logger.info("--- AuthController.create: La petición POST ha llegado ---")
    Logger.info("Parámetros completos recibidos: #{inspect(params)}")

    case Accounts.authenticate_user(user_params["email"], user_params["password"]) do
      {:ok, user} ->
        token_from_params = Map.get(params, "token")
        Logger.info("Token extraído del formulario: #{inspect(token_from_params)}")

        # Se usa un case para manejar explícitamente todos los escenarios del token.
        # El resultado de estas llamadas a helpers se devuelve como la respuesta final
        # de la acción `create`.
        case token_from_params do
          nil ->
            Logger.warning("--- ACCIÓN: Login Web (token es nulo). Redirigiendo... ---")
            handle_web_login(conn, user)
          "" ->
            Logger.warning("--- ACCIÓN: Login Web (token es string vacío). Redirigiendo... ---")
            handle_web_login(conn, user)
          token_string ->
            Logger.info("--- ACCIÓN: Login de Godot detectado. Reclamando token... ---")
            handle_godot_login(conn, user, token_string)
        end

      :error ->
        changeset = Accounts.change_user(%User{}, user_params)
        conn
        |> put_flash(:error, "Email o contraseña incorrectos.")
        |> put_status(:unprocessable_entity)
        |> render("new.html", changeset: changeset, token: Map.get(params, "token"))
    end
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> put_flash(:info, "Has cerrado sesión correctamente.")
    |> redirect(to: ~p"/")
  end

  # --- HELPERS PRIVADOS ---

  defp handle_web_login(conn, user) do
    conn
    |> put_session(:user_id, user.id)
    |> put_flash(:info, "Bienvenido de nuevo")
    |> redirect(to: ~p"/")
  end

  defp handle_godot_login(conn, user, token_string) do
    require Logger
    Logger.info("Buscando token válido: '#{token_string}'")

    case Auth.get_valid_login_token(token_string) do
      nil ->
        Logger.error("Token no encontrado o expirado. El cliente debería esperar a que se cree en el poll.")
        conn
        |> put_flash(:error, "Tu sesión de login para el juego ha expirado o es inválida. Por favor, reinicia el cliente.")
        |> redirect(to: "/")
        |> halt()

      login_token ->
        Logger.info("Token encontrado y válido. Reclamando para el usuario ##{user.id}")
        Auth.claim_login_token(login_token, user)
        # Renderiza la página de éxito para que la ventana del cliente de Godot la muestre
        conn
        |> put_view(RnxServerWeb.AuthHTML)
        |> render("success.html")
        |> halt() # Detenemos explícitamente la conexión aquí.
    end
  end
end