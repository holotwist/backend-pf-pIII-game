defmodule RnxServerWeb.PageController do
  use RnxServerWeb, :controller

  def home(conn, _params) do
    # El plug :fetch_current_user ya nos ha dado @current_user
    # si el usuario ha iniciado sesión.
    if current_user = conn.assigns[:current_user] do
      # Si existe, lo redirigimos a su perfil (nuestro "dashboard")
      redirect(conn, to: ~p"/users/#{current_user.id}")
    else
      # Si no, lo mandamos a la página de inicio de sesión
      redirect(conn, to: ~p"/auth/login")
    end
  end
end