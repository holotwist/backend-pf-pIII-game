defmodule RnxServer.Lobbies.LobbyPlayer do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "lobby_players" do
    belongs_to :lobby, RnxServer.Lobbies.Lobby, primary_key: true
    belongs_to :user, RnxServer.Accounts.User, primary_key: true
    field :score, :integer, default: 0
    field :is_ready, :boolean, default: false
    field :accuracy, :float
    field :max_combo, :integer
    field :catched, :integer
    field :missed, :integer
    field :results_submitted_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(lobby_player, attrs) do
    lobby_player
    |> cast(attrs, [:is_ready, :score, :accuracy, :max_combo, :results_submitted_at, :catched, :missed])
    |> validate_required([:is_ready])
  end
end