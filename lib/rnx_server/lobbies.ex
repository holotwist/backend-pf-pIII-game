defmodule RnxServer.Lobbies do
  @moduledoc """
  The Lobbies context.
  """

  import Ecto.Query, warn: false
  alias RnxServer.Repo
  alias RnxServer.Lobbies.Lobby
  alias RnxServer.Lobbies.LobbyPlayer
  alias RnxServer.Accounts.User

  def get_lobby_with_players_and_results!(id) do
    Lobby
    |> Repo.get!(id)
    |> Repo.preload(users: :lobby_players)
  end

  def create_lobby_with_players(player_ids, song_details) do
    users = Repo.all(from u in User, where: u.id in ^player_ids)

    %Lobby{}
    |> Lobby.changeset(%{
      song_name: song_details["song_name"],
      artist: song_details["artist"],
      game_mode: song_details["game_mode"],
      level_folder: song_details["level_folder"]
    })
    |> Ecto.Changeset.put_assoc(:users, users)
    |> Repo.insert()
  end

  def list_lobbies do
    Repo.all(Lobby)
  end

  def get_lobby!(id), do: Repo.get!(Lobby, id)

  def create_lobby(attrs) do
    %Lobby{}
    |> Lobby.changeset(attrs)
    |> Repo.insert()
  end

  def update_lobby(%Lobby{} = lobby, attrs) do
    lobby
    |> Lobby.changeset(attrs)
    |> Repo.update()
  end

  def delete_lobby(%Lobby{} = lobby) do
    Repo.delete(lobby)
  end

  def change_lobby(%Lobby{} = lobby, attrs \\ %{}) do
    Lobby.changeset(lobby, attrs)
  end

  def update_player_results(lobby_id, user_id, results) do
    # 1. Empezamos con los cambios que siempre se aplican.
    #    'set' requiere una Keyword List, así que la empezamos como tal.
    changes = [results_submitted_at: DateTime.utc_now()]

    # 2. Iteramos sobre los resultados recibidos y añadimos solo los que nos interesan
    #    a la lista de cambios, convirtiendo la clave a átomo en el proceso.
    changes =
      Enum.reduce(results, changes, fn {key, value}, acc ->
        # Usamos `Keyword.put` para añadir o reemplazar el valor en la lista.
        # `String.to_atom(key)` convierte "score" a :score, etc.
        Keyword.put(acc, String.to_atom(key), value)
      end)

    from(lp in LobbyPlayer, where: lp.lobby_id == ^lobby_id and lp.user_id == ^user_id)
    |> Repo.update_all(set: changes)
  end

  def get_lobby_players_with_users(lobby_id) do
    LobbyPlayer
    |> where(lobby_id: ^lobby_id)
    |> Repo.all()
    |> Repo.preload(:user)
  end

  @doc """
  Removes a single player from a lobby's join table.
  """
  def remove_player_from_lobby(lobby_id, user_id) do
    from(lp in LobbyPlayer, where: lp.lobby_id == ^lobby_id and lp.user_id == ^user_id)
    |> Repo.delete_all()
  end

  @doc """
  Finds an available public lobby that matches the criteria.
  """
  def find_available_lobby(game_mode, player_mmr) do
    mmr_range = 200.0
    care_about_mmr? = Application.get_env(:rnx_server, :care_about_mmr, false)
    # --- LEEMOS LA NUEVA CONFIGURACIÓN ---
    one_player_allowed? = Application.get_env(:rnx_server, :one_player_per_lobby_allowed, false)
    max_players = if one_player_allowed?, do: 1, else: 4

    query =
      from l in Lobby,
      where: l.state == "forming" and l.game_mode == ^game_mode,
      join: lp in assoc(l, :users),
      group_by: l.id,
      # --- USAMOS max_players ---
      having: count(lp.id) < ^max_players,
      order_by: [asc: l.inserted_at],
      select: l

    query =
      if care_about_mmr? do
        from [l, _lp] in query,
        where: l.average_mmr > ^(player_mmr - mmr_range) and l.average_mmr < ^(player_mmr + mmr_range)
      else
        query
      end

    Repo.one(query)
  end

  @doc """
  Adds a player to an existing lobby and updates the lobby's average MMR.
  """
  def add_player_to_lobby(%Lobby{} = lobby, %User{} = user) do
    # Añadimos la nueva relación
    Ecto.Changeset.change(lobby)
    |> Ecto.Changeset.put_assoc(:users, [user | lobby.users])
    |> Repo.update()
  end

  @doc """
  Gets a single lobby, returns nil if not found.
  """
  def get_lobby(id), do: Repo.get(Lobby, id)
end