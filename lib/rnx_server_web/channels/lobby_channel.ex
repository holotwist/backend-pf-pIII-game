defmodule RnxServerWeb.LobbyChannel do
  use RnxServerWeb, :channel
  alias RnxServer.Repo
  alias RnxServer.Lobbies
  alias RnxServer.Lobbies.LobbyPlayer
  alias RnxServer.Accounts
  alias RnxServer.Rating.Glicko2
  import Ecto.Query, warn: false
  require Logger

  @countdown_duration 10_000
  @lock_delay 5_000

  @impl true
  def join("lobby:" <> lobby_id, _payload, socket) do
    send(self(), :after_join)
    {:ok, assign(socket, :lobby_id, String.to_integer(lobby_id))}
  end

  @impl true
  def handle_in("player:set_ready_state", %{"ready" => is_ready}, socket) do
    user_id = socket.assigns.current_user_id
    lobby_id = socket.assigns.lobby_id
    from(lp in LobbyPlayer, where: lp.lobby_id == ^lobby_id and lp.user_id == ^user_id)
    |> Repo.update_all(set: [is_ready: is_ready])
    broadcast!(socket, "player_state_changed", %{user_id: user_id, is_ready: is_ready})
    check_all_players_ready(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_in("new_message", %{"message" => message}, socket) do
    user_id = socket.assigns.current_user_id
    user = RnxServer.Accounts.get_user!(user_id)
    broadcast!(socket, "new_message", %{username: user.username, message: message})
    {:noreply, socket}
  end

  @impl true
  def handle_in("submit_results", payload, socket) do
    user_id = socket.assigns.current_user_id
    lobby_id = socket.assigns.lobby_id

    Logger.info("[RESULTS] Lobby ##{lobby_id}: Received 'submit_results' from User ##{user_id}.")
    Logger.info("[RESULTS] Payload: #{inspect(payload)}")

    case Lobbies.update_player_results(lobby_id, user_id, payload) do
      {1, nil} ->
        Logger.info("[RESULTS] Lobby ##{lobby_id}: Successfully updated results for User ##{user_id} in DB.")

        query =
          from(lp in LobbyPlayer,
            where: lp.lobby_id == ^lobby_id and is_nil(lp.results_submitted_at),
            select: count()
          )

        pending_count = Repo.one(query)
        Logger.info("[RESULTS] Lobby ##{lobby_id}: Checked for pending players. Count = #{pending_count}")

        if pending_count == 0 do
          Logger.info("[RESULTS] Lobby ##{lobby_id}: All results are in! Finalizing match.")
          finalize_match(socket)
        else
          Logger.info("[RESULTS] Lobby ##{lobby_id}: Still waiting for #{pending_count} player(s).")
        end

      {0, nil} ->
        Logger.error("[RESULTS] Lobby ##{lobby_id}: update_player_results did not update any rows for User ##{user_id}.")

      other ->
        Logger.error("[RESULTS] Lobby ##{lobby_id}: Unexpected return from update_player_results: #{inspect(other)}")
    end

    {:noreply, socket}
  end

  defp finalize_match(socket) do
    lobby_id = socket.assigns.lobby_id
    all_players = Lobbies.get_lobby_players_with_users(lobby_id)
    ranked_players = Enum.sort_by(all_players, & &1.score, :desc)

    final_results =
      if Enum.count(ranked_players) < 2 do
        Logger.info("[RESULTS] Lobby ##{lobby_id}: Solo un jugador, omitiendo cálculo de MMR.")
        Enum.map(ranked_players, fn lobby_player ->
          user = lobby_player.user
          %{
            user_id: user.id,
            username: user.username,
            pfp_url: user.pfp_url,
            score: lobby_player.score,
            accuracy: lobby_player.accuracy,
            max_combo: lobby_player.max_combo,
            catched: lobby_player.catched,
            missed: lobby_player.missed,
            mmr_before: user.mmr,
            mmr_after: user.mmr
          }
        end)
      else
        Logger.info("[RESULTS] Lobby ##{lobby_id}: Calculando MMR para #{Enum.count(ranked_players)} jugadores.")
        glicko_players =
          Enum.map(ranked_players, fn lp ->
            %Glicko2.Player{
              rating: lp.user.mmr,
              rd: lp.user.mmr_rd,
              volatility: lp.user.mmr_volatility
            }
          end)

        matches =
          for {p1, idx1} <- Enum.with_index(glicko_players),
              {p2, idx2} <- Enum.with_index(glicko_players),
              idx1 < idx2 do
            %{white: p1, black: p2, outcome: 1.0}
          end

        updated_glicko_players = Glicko2.rate(matches)

        Enum.zip(ranked_players, updated_glicko_players)
        |> Enum.map(fn {lobby_player, glicko_data} ->
          user = lobby_player.user
          new_ratings = %{
            mmr: glicko_data.rating,
            mmr_rd: glicko_data.rd,
            volatility: glicko_data.volatility
          }
          {:ok, updated_user} = Accounts.update_user(user, new_ratings)

          %{
            user_id: user.id,
            username: user.username,
            pfp_url: user.pfp_url,
            score: lobby_player.score,
            accuracy: lobby_player.accuracy,
            max_combo: lobby_player.max_combo,
            catched: lobby_player.catched,
            missed: lobby_player.missed,
            mmr_before: user.mmr,
            mmr_after: updated_user.mmr
          }
        end)
      end

    Logger.info("[RESULTS] Lobby ##{lobby_id}: Broadcasting 'lobby_results_finalized'.")
    broadcast!(socket, "lobby_results_finalized", %{results: final_results})

    # Una vez que hemos enviado los resultados, el lobby ya no es necesario.
    # Lo obtenemos de la base de datos y lo eliminamos.
    Logger.info("[CLEANUP] Deleting Lobby ##{lobby_id} from database.")
    lobby = Lobbies.get_lobby!(lobby_id)
    Lobbies.delete_lobby(lobby)
  end

  @impl true
  def handle_info(:after_join, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(:lock_countdown, socket) do
    broadcast!(socket, "countdown_lock", %{})
    {:noreply, socket}
  end

  @impl true
  def handle_info(:start_game, socket) do
    broadcast!(socket, "match_starting", %{})
    {:noreply, socket}
  end

  defp check_all_players_ready(socket) do
    lobby_id = socket.assigns.lobby_id
    query = from(lp in LobbyPlayer, where: lp.lobby_id == ^lobby_id, select: lp.is_ready)
    ready_states = Repo.all(query)

    if Enum.all?(ready_states) and not Enum.empty?(ready_states) do
      broadcast!(socket, "countdown_started", %{duration: @countdown_duration / 1000})
      lock_timer = Process.send_after(self(), :lock_countdown, @lock_delay)
      start_timer = Process.send_after(self(), :start_game, @countdown_duration)
      assign(socket, :lock_timer, lock_timer) |> assign(:start_timer, start_timer)
    else
      if timer_ref = socket.assigns[:lock_timer], do: Process.cancel_timer(timer_ref)
      if timer_ref = socket.assigns[:start_timer], do: Process.cancel_timer(timer_ref)
      broadcast!(socket, "countdown_cancelled", %{})
      assign(socket, :lock_timer, nil) |> assign(:start_timer, nil)
    end
  end

  @impl true
  def terminate(_reason, socket) do
    lobby_id = socket.assigns.lobby_id
    user_id = socket.assigns.current_user_id

    Logger.info("[LOBBY_LEAVE] User ##{user_id} is leaving Lobby ##{lobby_id}.")
    
    # 1. Eliminamos al jugador de la tabla de unión.
    Lobbies.remove_player_from_lobby(lobby_id, user_id)
    
    # 2. Comprobamos si el lobby todavía existe.
    #    Puede que ya haya sido eliminado por el proceso de finalize_match.
    case Lobbies.get_lobby(lobby_id) do
      nil ->
        # El lobby ya no existe, nuestro trabajo aquí ha terminado.
        Logger.info("[LOBBY_LEAVE] Lobby ##{lobby_id} was already deleted. No further action needed.")

      %Lobbies.Lobby{} = lobby ->
        # El lobby todavía existe, comprobemos si está vacío.
        query = from(lp in LobbyPlayer, where: lp.lobby_id == ^lobby_id, select: count())
        remaining_count = Repo.one(query)
        
        Logger.info("[LOBBY_LEAVE] Lobby ##{lobby_id} has #{remaining_count} players remaining.")
        
        if remaining_count == 0 do
          Logger.info("[LOBBY_LEAVE] Lobby ##{lobby_id} is empty. Deleting from database.")
          Lobbies.delete_lobby(lobby)
        end
    end
    
    :ok
  end
end