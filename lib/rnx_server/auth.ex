defmodule RnxServer.Auth do
  @moduledoc """
  The Auth context.
  """

  import Ecto.Query, warn: false
  alias RnxServer.Repo
  alias RnxServer.Auth.LoginToken
  alias RnxServer.Accounts.User

  def get_valid_login_token(token) do
    from(lt in LoginToken,
      where: lt.token == ^token and lt.expires_at > ^DateTime.utc_now()
    )
    |> Repo.one()
  end
  
  def create_login_token(token_string) do
    %LoginToken{}
    |> Ecto.Changeset.cast(%{token: token_string, expires_at: DateTime.add(DateTime.utc_now(), 300, :second)}, [:token, :expires_at])
    |> Ecto.Changeset.validate_required([:token, :expires_at])
    |> Repo.insert()
  end

  def claim_login_token(%LoginToken{} = login_token, %User{} = user) do
    login_token
    |> Ecto.Changeset.change(user_id: user.id)
    |> Repo.update()
  end

  def get_login_token_for_polling(token) do
    Repo.get_by(LoginToken, token: token)
  end
end