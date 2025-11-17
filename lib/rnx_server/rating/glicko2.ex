# lib/rnx_server/rating/glicko2.ex
defmodule RnxServer.Rating.Glicko2 do
  @moduledoc """
  An implementation of the Glicko-2 rating system.
  Based on the paper by Mark Glickman: http://www.glicko.net/glicko/glicko2.pdf
  """

  defmodule Player do
    @moduledoc "Represents a player with Glicko-2 ratings."
    defstruct rating: 1500.0, rd: 350.0, volatility: 0.06
  end

  @tau 0.5 # The system constant, τ
  @scaling_factor 173.7178

  @doc """
  Calculates new ratings for a list of players based on match outcomes.

  Matches should be a list of maps, each with:
  - `:white`: The first player (`%Player{}`)
  - `:black`: The second player (`%Player{}`)
  - `:outcome`: 1.0 for white win, 0.5 for draw, 0.0 for black win.
  """
  def rate(matches, opts \\ []) do
    tau = Keyword.get(opts, :tau, @tau)

    players =
      matches
      |> Enum.flat_map(fn m -> [m.white, m.black] end)
      |> Enum.uniq()

    player_matches =
      for player <- players do
        player_matches =
          Enum.filter(matches, fn m ->
            m.white == player || m.black == player
          end)

        {player, player_matches}
      end

    Enum.map(player_matches, fn {player, p_matches} ->
      update_player(player, p_matches, tau)
    end)
  end

  defp update_player(%Player{} = player, matches, tau) do
    if matches == [] do
      # If a player has no matches, only update their RD
      phi_squared = :math.pow(to_g2_scale(player.rd), 2)
      sigma_squared = :math.pow(player.volatility, 2)
      phi_new_scaled = :math.sqrt(phi_squared + sigma_squared)

      %{player | rd: from_g2_scale(phi_new_scaled)}
    else
      # Step 2: Convert to Glicko-2 scale
      mu = to_g2_scale(player.rating)
      phi = to_g2_scale(player.rd)
      sigma = player.volatility

      # Step 3: Compute the estimated variance (v)
      {v, delta} =
        Enum.reduce(matches, {0, 0}, fn match, {v_acc, delta_acc} ->
          opponent = if match.white == player, do: match.black, else: match.white
          outcome = if match.white == player, do: match.outcome, else: 1.0 - match.outcome

          mu_j = to_g2_scale(opponent.rating)
          phi_j = to_g2_scale(opponent.rd)
          g_phi_j = g(phi_j)
          e = e(mu, mu_j, g_phi_j)

          v_new = v_acc + :math.pow(g_phi_j, 2) * e * (1 - e)
          delta_new = delta_acc + g_phi_j * (outcome - e)
          {v_new, delta_new}
        end)

      v = :math.pow(v, -1)
      delta = v * delta

      # Step 4: Determine new volatility
      sigma_new = new_volatility(delta, phi, v, sigma, tau)

      # Step 5: Update rating and RD
      phi_star = :math.sqrt(:math.pow(phi, 2) + :math.pow(sigma_new, 2))
      phi_new = 1 / :math.sqrt(1 / :math.pow(phi_star, 2) + 1 / v)
      mu_new = mu + :math.pow(phi_new, 2) * (delta / v)

      # Step 6 & 7: Convert back to Glicko scale
      %{
        rating: from_g2_scale(mu_new),
        rd: from_g2_scale(phi_new),
        volatility: sigma_new
      }
    end
  end

  defp new_volatility(delta, phi, v, sigma, tau) do
    a = :math.log(:math.pow(sigma, 2))
    delta_sq = :math.pow(delta, 2)

    f = fn x ->
      ex = :math.exp(x)
      (ex * (delta_sq - :math.pow(phi, 2) - v - ex)) / (2 * :math.pow(:math.pow(phi, 2) + v + ex, 2)) - (x - a) / :math.pow(tau, 2)
    end

    # Bisection method to find the root
    epsilon = 0.000001
    # Step 4.2
    {a_big, b_big} =
      cond do
        delta_sq > :math.pow(phi, 2) + v -> {a, :math.log(delta_sq - :math.pow(phi, 2) - v)}
        true ->
          k = 1
          find_b_big(k, a, delta_sq, phi, v, f)
      end

    # Step 4.4
    fa = f.(a_big)
    fb = f.(b_big)

    # Step 4.5
    {a_final, _b_final} = converge_loop(a_big, b_big, fa, fb, f, epsilon)

    :math.exp(a_final / 2)
  end

  defp find_b_big(k, a, delta_sq, phi, v, f) do
    b_k = a - k * @tau
    if f.(b_k) < 0, do: find_b_big(k + 1, a, delta_sq, phi, v, f), else: {a, b_k}
  end

  defp converge_loop(a, b, fa, fb, f, epsilon) do
    if abs(b - a) <= epsilon do
      {a, b}
    else
      c = a + (a - b) * fa / (fb - fa)
      fc = f.(c)
      if fc * fb < 0, do: converge_loop(b, c, fb, fc, f, epsilon), else: converge_loop(a, c, fa * 0.5, fc, f, epsilon)
    end
  end

  defp g(phi), do: 1 / :math.sqrt(1 + 3 * :math.pow(phi, 2) / :math.pow(:math.pi(), 2))
  defp e(mu, mu_j, g_phi_j), do: 1 / (1 + :math.exp(-g_phi_j * (mu - mu_j)))

  defp to_g2_scale(val), do: (val - 1500.0) / @scaling_factor
  defp from_g2_scale(val), do: val * @scaling_factor + 1500.0
end