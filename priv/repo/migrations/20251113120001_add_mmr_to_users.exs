defmodule RnxServer.Repo.Migrations.AddMmrToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Glicko2 default rating is 1500, so we use that as a starting point.
      add :mmr, :float, null: false, default: 1500.0
    end
  end
end