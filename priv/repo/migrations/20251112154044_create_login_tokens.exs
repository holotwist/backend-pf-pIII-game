defmodule RnxServer.Repo.Migrations.CreateLoginTokens do
  use Ecto.Migration

  def change do
    create table(:login_tokens) do
      add :token, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :user_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:login_tokens, [:token])
    create index(:login_tokens, [:user_id])
  end
end
