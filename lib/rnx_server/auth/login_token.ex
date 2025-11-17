defmodule RnxServer.Auth.LoginToken do
  use Ecto.Schema
  import Ecto.Changeset

  schema "login_tokens" do
    field :token, :string
    field :expires_at, :utc_datetime
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(login_token, attrs) do
    login_token
    |> cast(attrs, [:token, :expires_at])
    |> validate_required([:token, :expires_at])
    |> unique_constraint(:token)
  end
end
