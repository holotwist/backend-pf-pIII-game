defmodule RnxServer.Lobbies.Lobby do
  use Ecto.Schema
  import Ecto.Changeset
  alias RnxServer.Accounts.User
  alias RnxServer.Lobbies.LobbyPlayer

  @derive {Jason.Encoder, only: [:id, :state, :song_name, :artist, :game_mode, :level_folder, :average_mmr]}

  schema "lobbies" do
    field :state, :string, default: "forming"
    field :song_name, :string
    field :artist, :string
    field :game_mode, :string
    field :level_folder, :string
    field :average_mmr, :float, default: 0.0

    many_to_many :users, User, join_through: LobbyPlayer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(lobby, attrs) do
    lobby
    |> cast(attrs, [:state, :song_name, :artist, :game_mode, :level_folder, :average_mmr])
    |> validate_required([:state])
  end
end