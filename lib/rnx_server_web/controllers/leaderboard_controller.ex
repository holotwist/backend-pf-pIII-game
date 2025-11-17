defmodule RnxServerWeb.LeaderboardController do
  use RnxServerWeb, :controller

  alias RnxServer.Accounts

  def index(conn, %{"game_mode" => game_mode}) do
    # Obtenemos los usuarios y les añadimos un índice para el ranking
    users_with_rank = Accounts.list_users_by_mmr() |> Enum.with_index()
    
    render(conn, :index, users: users_with_rank, game_mode: game_mode)
  end
end