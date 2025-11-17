defmodule RnxServer.Repo.Migrations.AddResultsToLobbyPlayers do
  use Ecto.Migration

  def change do
    alter table(:lobby_players) do
      add :accuracy, :float
      add :max_combo, :integer
      add :results_submitted_at, :utc_datetime
    end
  end
end