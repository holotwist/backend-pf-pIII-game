defmodule RnxServerWeb.UserController do
  use RnxServerWeb, :controller
  alias RnxServer.Accounts
  alias RnxServer.Auth
  alias RnxServer.Accounts.User

  def show(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    render(conn, :show, user: user)
  end

  def new(conn, params) do
    # Si hay un usuario en sesión Y NO es el flujo de Godot, redirigir.
    if conn.assigns.current_user && !params["token"] do
      redirect(conn, to: "/users/#{conn.assigns.current_user.id}")
    else
      # Si no, mostrar la página de registro con el token.
      changeset = Accounts.change_user(%User{})
      render(conn, "new.html", changeset: changeset, token: Map.get(params, "token"))
    end
  end

  def create(conn, %{"_csrf_token" => _csrf, "user" => user_params} = params) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        if token_string = Map.get(params, "token") do
          handle_godot_registration(conn, user, token_string)
        else
          handle_web_registration(conn, user)
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render("new.html", changeset: changeset, token: Map.get(params, "token"))
    end
  end
  
  def edit(conn, _params) do
    changeset = Accounts.change_user_update(conn.assigns.current_user)
    render(conn, :edit, changeset: changeset)
  end

  def update(conn, %{"_csrf_token" => _csrf, "user" => user_params}) do
    IO.puts("\n--- INICIANDO ACTUALIZACIÓN DE PERFIL ---")
    IO.inspect(user_params, label: "1. Parámetros recibidos del formulario")

    user = conn.assigns.current_user
    pfp_upload = user_params["pfp"]

    case handle_pfp_upload(pfp_upload, user) do
      {:ok, new_pfp_url} ->
        IO.inspect(new_pfp_url, label: "2. Resultado de handle_pfp_upload (Éxito)")

        attrs_for_ecto =
          user_params
          |> Map.drop(["pfp"])
          |> Map.put("pfp_url", new_pfp_url)

        IO.inspect(attrs_for_ecto, label: "3. Atributos limpios para Ecto")

        case Accounts.update_user(user, attrs_for_ecto) do
          {:ok, updated_user} ->
            IO.puts("4. Cuentas.update_user tuvo ÉXITO. Redirigiendo...")
            conn
            |> put_flash(:info, "Perfil actualizado correctamente.")
            |> redirect(to: ~p"/users/#{updated_user.id}")

          {:error, %Ecto.Changeset{} = changeset} ->
            IO.inspect(changeset, label: "4. Cuentas.update_user FALLÓ. Changeset inválido")
            conn
            |> put_flash(:error, "No se pudo guardar el perfil. Revisa los errores.")
            |> render(:edit, changeset: changeset)
        end

      {:error, reason} ->
        IO.inspect(reason, label: "2. Resultado de handle_pfp_upload (FALLO)")
        changeset = Accounts.change_user_update(user, user_params)
        conn
        |> put_flash(:error, "Error al subir la imagen: #{reason}")
        |> render(:edit, changeset: changeset)
    end
  end

  # --- Helpers Privados ---

  defp handle_web_registration(conn, user) do
    conn
    |> put_session(:user_id, user.id)
    |> put_flash(:info, "¡Cuenta creada! Has iniciado sesión.")
    |> redirect(to: ~p"/")
  end

  defp handle_godot_registration(conn, user, token_string) do
    case Auth.get_valid_login_token(token_string) do
      nil ->
        conn
        |> put_flash(:error, "Tu sesión de registro expiró. Por favor, vuelve al juego e inténtalo de nuevo.")
        |> redirect(to: ~p"/")
      
      login_token ->
        Auth.claim_login_token(login_token, user)
        conn
        |> put_view(RnxServerWeb.AuthHTML)
        |> render("success.html")
    end
  end
  
  # Si no se sube ningún archivo nuevo
  defp handle_pfp_upload(%Plug.Upload{filename: ""}, user), do: {:ok, user.pfp_url}
  defp handle_pfp_upload(nil, user), do: {:ok, user.pfp_url}
  
  # Si se sube un archivo nuevo
  defp handle_pfp_upload(%Plug.Upload{} = pfp_upload, user) do
    upload_dir = "users/pfp"
    static_dir = Path.join(Application.app_dir(:rnx_server, "priv/static/uploads"), upload_dir)
    extension = Path.extname(pfp_upload.filename)
    filename = "#{user.id}-#{System.system_time(:millisecond)}#{extension}"
    filepath = Path.join(static_dir, filename)

    File.mkdir_p!(static_dir)

    case File.cp(pfp_upload.path, filepath) do
      :ok ->
        if user.pfp_url do
          old_path = Path.join(Application.app_dir(:rnx_server, "priv/static"), user.pfp_url)
          if File.exists?(old_path), do: File.rm(old_path)
        end
        {:ok, "/uploads/#{upload_dir}/#{filename}"}
      {:error, reason} ->
        {:error, Atom.to_string(reason)}
    end
  end
end