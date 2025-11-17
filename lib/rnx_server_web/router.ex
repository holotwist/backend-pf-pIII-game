defmodule RnxServerWeb.Router do
  use RnxServerWeb, :router
  alias RnxServer.Accounts

  # --- PIPELINES ---
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RnxServerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug RnxServerWeb.ClaimGodotTokenPlug
  end

  pipeline :browser_auth do
    plug RnxServerWeb.AuthPlugWeb
  end

  pipeline :guest_only do
    plug RnxServerWeb.RedirectIfLoggedInPlug
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_auth do
    plug :accepts, ["json", "multipart/form-data"]
    plug RnxServerWeb.AuthPlug
  end

  # --- RUTAS WEB ---
  scope "/", RnxServerWeb do
    # Todas las rutas de navegador pasan por este pipeline principal
    pipe_through :browser

    # Rutas solo para invitados (login, registro)
    pipe_through :guest_only
    get "/auth/login", AuthController, :new
    post "/auth/login", AuthController, :create
    get "/users/register", UserController, :new
    post "/users/register", UserController, :create
  end

  scope "/", RnxServerWeb do
    # Rutas para usuarios autenticados
    pipe_through [:browser, :browser_auth]

    get "/users/settings", UserController, :edit
    put "/users/settings", UserController, :update
    delete "/auth/logout", AuthController, :delete
  end

  scope "/", RnxServerWeb do
    # Rutas públicas (no requieren ni invitado ni autenticado)
    pipe_through :browser

    get "/", PageController, :home
    get "/users/:id", UserController, :show
    get "/leaderboard/:game_mode", LeaderboardController, :index
  end

  # --- RUTAS API ---
  scope "/api", RnxServerWeb do
    pipe_through :api
    get "/auth/poll/:token", Api.AuthController, :poll
    get "/songs/random", Api.SongController, :random
  end

  scope "/api", RnxServerWeb do
    pipe_through :api_auth
    get "/users/me", Api.UserController, :show
    put "/users/me", Api.UserController, :update
    post "/users/me/pfp", Api.UserController, :upload_pfp
  end

  # --- RUTAS DE DESARROLLO ---
  if Application.compile_env(:rnx_server, :dev_routes) do
    import Phoenix.LiveDashboard.Router
    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: RnxServerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  # --- FUNCIÓN HELPER ---
  defp fetch_current_user(conn, _) do
    if user_id = get_session(conn, :user_id) do
      assign(conn, :current_user, Accounts.get_user!(user_id))
    else
      assign(conn, :current_user, nil)
    end
  end
end