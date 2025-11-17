defmodule RnxServer.Repo.Migrations.AddReadyStateToLobbyPlayers do
  use Ecto.Migration

  def change do
    alter table(:lobby_players) do
      add :is_ready, :boolean, default: false, null: false
    end
  end
end