# lib/rnx_server/accounts.ex

defmodule RnxServer.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias RnxServer.Repo
  alias RnxServer.Accounts.User

  @doc """
  Returns the list of users.
  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Creates a user using the registration changeset, which handles password hashing.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.
  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs)
  end

  @doc """
  Authenticates a user by email and password.
  """
  def authenticate_user(email, password) do
    user = get_user_by_email(email)

    if user && Pbkdf2.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      :error
    end
  end

  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user update changes.
  """
  def change_user_update(%User{} = user, attrs \\ %{}) do
    User.update_changeset(user, attrs)
  end

  @doc """
  Returns the list of users sorted by MMR.
  """
  def list_users_by_mmr do
    from(u in User,
      order_by: [desc: u.mmr],
      limit: 100
    )
    |> Repo.all()
  end
end