defmodule RnxServer.Repo.Migrations.CreateLobbies do
  use Ecto.Migration

  def change do
    create table(:lobbies) do
      add :state, :string, null: false, default: "forming"
      add :song_name, :string
      add :artist, :string
      add :game_mode, :string
      add :level_folder, :string

      timestamps(type: :utc_datetime)
    end

    create table(:lobby_players) do
      add :lobby_id, references(:lobbies, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :score, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:lobby_players, [:lobby_id])
    create index(:lobby_players, [:user_id])
    create unique_index(:lobby_players, [:lobby_id, :user_id])
  end
end