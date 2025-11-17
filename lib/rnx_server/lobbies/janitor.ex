defmodule RnxServer.Lobbies.Janitor do
  use GenServer
  require Logger

  alias RnxServer.Repo
  alias RnxServer.Lobbies.Lobby
  alias RnxServer.Lobbies.LobbyPlayer
  import Ecto.Query

  @sweep_interval :timer.minutes(5)
  @max_lobby_age_in_seconds 300 # 5 minutos

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Lobby Janitor started. Sweeping for old lobbies every #{div(@sweep_interval, 60_000)} minutes.")
    :timer.send_interval(@sweep_interval, self(), :sweep)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sweep, state) do
    Logger.info("[JANITOR] Sweeping for old, empty lobbies...")

    cutoff_datetime = DateTime.add(DateTime.utc_now(), -@max_lobby_age_in_seconds, :second)

    # Estrategia diferente y más robusta:
    # 1. Hacemos un LEFT JOIN desde Lobbies a LobbyPlayers.
    # 2. Buscamos lobbies donde la unión no encontró un LobbyPlayer (es decir, lp.lobby_id es nulo).
    # 3. Y que además sean más antiguos que nuestro tiempo de corte.
    query =
      from l in Lobby,
      left_join: lp in LobbyPlayer, on: l.id == lp.lobby_id,
      where: is_nil(lp.lobby_id) and l.inserted_at < ^cutoff_datetime,
      select: l.id

    lobby_ids_to_delete = Repo.all(query)

    if Enum.any?(lobby_ids_to_delete) do
      Logger.info("[JANITOR] Found #{Enum.count(lobby_ids_to_delete)} orphaned lobbies to delete: #{inspect(lobby_ids_to_delete)}")
      
      delete_query = from l in Lobby, where: l.id in ^lobby_ids_to_delete
      
      # delete_all devuelve {num_deleted, nil}, lo usamos para loguear
      case Repo.delete_all(delete_query) do
        {count, nil} -> Logger.info("[JANITOR] Successfully deleted #{count} lobbies.")
        {:error, reason} -> Logger.error("[JANITOR] Error deleting lobbies: #{inspect(reason)}")
      end
    else
      Logger.info("[JANITOR] No orphaned lobbies found.")
    end

    {:noreply, state}
  end
end