defmodule RnxServer.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias RnxServer.Lobbies.Lobby
  alias RnxServer.Lobbies.LobbyPlayer

  @derive {Jason.Encoder, only: [:id, :username, :mmr, :pfp_url]}

  schema "users" do
    field :username, :string
    field :email, :string
    field :password_hash, :string
    field :mmr, :float, default: 1500.0
    field :pfp_url, :string
    field :mmr_rd, :float, default: 350.0
    field :mmr_volatility, :float, default: 0.06

    many_to_many :lobbies, Lobby, join_through: LobbyPlayer

    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true
    field :pfp, :any, virtual: true
    
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :password_hash, :mmr, :pfp_url])
    |> validate_required([:username, :email, :password_hash])
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> put_password_hash()
  end
  
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :password, :password_confirmation])
    |> validate_required([:username, :email, :password, :password_confirmation])
    |> validate_length(:password, min: 8)
    |> validate_confirmation(:password)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
    |> put_password_hash()
  end
  
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :pfp_url, :mmr, :mmr_rd, :mmr_volatility])
    |> validate_required([:username])
  end

  defp put_password_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: pass}} ->
        put_change(changeset, :password_hash, Pbkdf2.hash_pwd_salt(pass))
      _ ->
        changeset
    end
  end
end