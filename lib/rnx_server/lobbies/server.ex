defmodule RnxServer.Lobbies.Server do
  use GenServer
  require Logger

  alias RnxServer.Lobbies
  alias RnxServer.Songs.Scanner
  alias RnxServer.Accounts.User
  alias RnxServer.Repo

  # --- Client API ---
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def find_or_create_lobby(user, game_mode) do
    GenServer.call(__MODULE__, {:find_or_create_lobby, user, game_mode})
  end

  # --- GenServer Callbacks ---
  @impl true
  def init(_state) do
    Logger.info("Lobby Server started.")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:find_or_create_lobby, %User{} = user, game_mode}, _from, state) do
    lobby = Lobbies.find_available_lobby(game_mode, user.mmr)

    response =
      case lobby do
        # Caso 1: Se encontró un lobby existente
        %Lobbies.Lobby{} = existing_lobby ->
          Logger.info("[LOBBY_SERVER] Found existing lobby ##{existing_lobby.id} for user ##{user.id}.")
          
          existing_lobby = Repo.preload(existing_lobby, :users)
          all_players = [user | existing_lobby.users]
          new_avg_mmr = Enum.reduce(all_players, 0, &(&1.mmr + &2)) / Enum.count(all_players)

          changeset = Ecto.Changeset.change(existing_lobby, %{average_mmr: new_avg_mmr})
          changeset = Ecto.Changeset.put_assoc(changeset, :users, all_players)
          
          {:ok, updated_lobby} = Repo.update(changeset)

          # Un solo broadcast notifica a todos
          # los suscriptores del canal del lobby.
          RnxServerWeb.Endpoint.broadcast("lobby:#{updated_lobby.id}", "player_joined", %{user: user})
          
          {:ok, updated_lobby}

        # Caso 2: No se encontró lobby, se crea uno nuevo (sin cambios en esta parte)
        nil ->
          Logger.info("[LOBBY_SERVER] No available lobby found. Creating new one for user ##{user.id}.")
          
          song_details = Scanner.get_random_song(game_mode)
          
          if song_details do
            attrs = %{
              song_name: song_details["songName"] || song_details["song_name"],
              artist: song_details["artist"],
              game_mode: song_details["game_mode"],
              level_folder: song_details["level_folder"],
              average_mmr: user.mmr
            }

            changeset =
              %Lobbies.Lobby{}
              |> Lobbies.change_lobby(attrs)
              |> Ecto.Changeset.put_assoc(:users, [user])

            case Repo.insert(changeset) do
              {:ok, new_lobby} -> {:ok, {new_lobby, song_details}}
              {:error, changeset} -> {:error, changeset}
            end
          else
            {:error, :no_songs_available}
          end
      end

    {:reply, response, state}
  end
end