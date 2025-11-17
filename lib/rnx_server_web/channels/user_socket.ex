defmodule RnxServerWeb.UserSocket do
  use Phoenix.Socket

  channel "user:*", RnxServerWeb.UserChannel
  channel "matchmaking", RnxServerWeb.MatchmakingChannel
  channel "lobby:*", RnxServerWeb.LobbyChannel

  @max_age 2_592_000 # 30 days in seconds

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Phoenix.Token.verify(socket, "user_token", token, max_age: @max_age) do
      {:ok, user_id} ->
        {:ok, assign(socket, :current_user_id, user_id)}

      {:error, _reason} ->
        :error
    end
  end

  # This is called when no valid token is provided.
  @impl true
  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_user_id}"
end