defmodule RnxServerWeb.Api.SongController do
  use RnxServerWeb, :controller
  alias RnxServer.Songs.Scanner

  def random(conn, _params) do
    # Intentamos obtener una canción de cualquier modo de juego
    song = Scanner.get_random_song("game1") || Scanner.get_random_song("game2")

    if song do
      json(conn, song)
    else
      conn
      |> put_status(:not_found)
      |> json(%{error: "No songs available"})
    end
  end
end