defmodule RnxServerWeb.Api.UserController do
  use RnxServerWeb, :controller
  alias RnxServer.Accounts

  action_fallback RnxServerWeb.Api.FallbackController

  def show(conn, _params) do
    # El usuario se inyecta en el conn gracias a AuthPlug
    json(conn, conn.assigns.current_user)
  end

  def update(conn, user_params) do
    with {:ok, user} <- Accounts.update_user(conn.assigns.current_user, user_params) do
      json(conn, user)
    else
      {:error, changeset} ->
        # La llamada al fallback se encargará de esto.
        {:error, changeset}
    end
  end

  def upload_pfp(conn, %{"pfp" => pfp_upload}) do
    user = conn.assigns.current_user
    
    # Definir el directorio público para las subidas
    upload_dir = "users/pfp"
    static_dir = Path.join(Application.app_dir(:rnx_server, "priv/static/uploads"), upload_dir)
    
    # Generar un nombre de archivo único
    extension = Path.extname(pfp_upload.filename)
    filename = "#{user.id}-#{System.system_time(:millisecond)}#{extension}"
    filepath = Path.join(static_dir, filename)

    # Asegurarse de que el directorio existe
    File.mkdir_p!(static_dir)

    # Mover el archivo subido
    case File.cp(pfp_upload.path, filepath) do
      :ok ->
        # Si había una foto antigua, la borramos
        if user.pfp_url do
          old_path = Path.join(Application.app_dir(:rnx_server, "priv/static"), user.pfp_url)
          File.rm(old_path)
        end

        # Actualizar la base de datos
        pfp_url = "/uploads/#{upload_dir}/#{filename}"
        with {:ok, updated_user} <- Accounts.update_user(user, %{pfp_url: pfp_url}) do
          json(conn, updated_user)
        end
      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to save file: #{reason}"})
    end
  end
end