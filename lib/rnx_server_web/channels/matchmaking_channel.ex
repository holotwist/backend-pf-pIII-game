defmodule RnxServerWeb.MatchmakingChannel do
  use RnxServerWeb, :channel
  alias RnxServer.Accounts
  alias RnxServer.Lobbies.Server
  alias RnxServer.Repo
  alias RnxServer.Songs.Scanner

  @impl true
  def join("matchmaking", _payload, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_in("find_game", %{"game_mode" => game_mode}, socket) do
    user = Accounts.get_user!(socket.assigns.current_user_id)

    case Server.find_or_create_lobby(user, game_mode) do
      # Caso 1: Se creó un lobby nuevo. Recibimos el lobby y los detalles de la canción.
      {:ok, {lobby, song_details}} ->
        lobby = Repo.preload(lobby, :users)
        
        # Jason.encode! |> Jason.decode! es un truco para convertir el struct a un mapa de strings.
        lobby_map = Jason.decode!(Jason.encode!(lobby))
        
        # Combinamos el mapa del lobby con los detalles completos de la canción.
        full_song_info = Map.merge(lobby_map, song_details)

        payload = %{
          lobby_id: lobby.id,
          players: lobby.users,
          song: full_song_info
        }
        push(socket, "game_found", payload)

      # Caso 2: Se unió a un lobby existente. Solo recibimos el lobby.
      {:ok, lobby} ->
        lobby = Repo.preload(lobby, :users)
        
        all_songs_for_mode = Scanner.get_all_songs(lobby.game_mode)
        song_details = Enum.find(all_songs_for_mode, %{}, fn s -> s["level_folder"] == lobby.level_folder end)

        lobby_map = Jason.decode!(Jason.encode!(lobby))
        full_song_info = Map.merge(lobby_map, song_details)

        payload = %{
          lobby_id: lobby.id,
          players: lobby.users,
          song: full_song_info
        }
        push(socket, "game_found", payload)
        
      {:error, reason} ->
        push(socket, "error", %{reason: Atom.to_string(reason)})
    end

    {:noreply, socket}
  end
end