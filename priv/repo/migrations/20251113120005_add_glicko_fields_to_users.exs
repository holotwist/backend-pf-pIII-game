defmodule RnxServer.Repo.Migrations.AddGlickoFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # Glicko2 defaults: RD starts high, volatility is low.
      add :mmr_rd, :float, null: false, default: 350.0
      add :mmr_volatility, :float, null: false, default: 0.06
    end
  end
end