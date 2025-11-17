defmodule RnxServer.Repo.Migrations.AddAverageMmrToLobbies do
  use Ecto.Migration

  def change do
    alter table(:lobbies) do
      add :average_mmr, :float, default: 0.0
    end
  end
end
