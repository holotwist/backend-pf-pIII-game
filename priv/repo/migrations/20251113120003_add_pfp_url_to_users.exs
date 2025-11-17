defmodule RnxServer.Repo.Migrations.AddPfpUrlToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # This will store the public path to the user's profile picture.
      add :pfp_url, :string
    end
  end
end