defmodule RnxServer.Repo.Migrations.AddGame2ResultsToLobbyPlayers do
  use Ecto.Migration

  def change do
    alter table(:lobby_players) do
      add :catched, :integer
      add :missed, :integer
    end
  end
end