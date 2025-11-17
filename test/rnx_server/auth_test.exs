defmodule RnxServer.AuthTest do
  use RnxServer.DataCase

  alias RnxServer.Auth

  describe "login_tokens" do
    alias RnxServer.Auth.LoginToken

    import RnxServer.AuthFixtures

    @invalid_attrs %{token: nil, expires_at: nil}

    test "list_login_tokens/0 returns all login_tokens" do
      login_token = login_token_fixture()
      assert Auth.list_login_tokens() == [login_token]
    end

    test "get_login_token!/1 returns the login_token with given id" do
      login_token = login_token_fixture()
      assert Auth.get_login_token!(login_token.id) == login_token
    end

    test "create_login_token/1 with valid data creates a login_token" do
      valid_attrs = %{token: "some token", expires_at: ~U[2025-11-11 15:40:00Z]}

      assert {:ok, %LoginToken{} = login_token} = Auth.create_login_token(valid_attrs)
      assert login_token.token == "some token"
      assert login_token.expires_at == ~U[2025-11-11 15:40:00Z]
    end

    test "create_login_token/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Auth.create_login_token(@invalid_attrs)
    end

    test "update_login_token/2 with valid data updates the login_token" do
      login_token = login_token_fixture()
      update_attrs = %{token: "some updated token", expires_at: ~U[2025-11-12 15:40:00Z]}

      assert {:ok, %LoginToken{} = login_token} = Auth.update_login_token(login_token, update_attrs)
      assert login_token.token == "some updated token"
      assert login_token.expires_at == ~U[2025-11-12 15:40:00Z]
    end

    test "update_login_token/2 with invalid data returns error changeset" do
      login_token = login_token_fixture()
      assert {:error, %Ecto.Changeset{}} = Auth.update_login_token(login_token, @invalid_attrs)
      assert login_token == Auth.get_login_token!(login_token.id)
    end

    test "delete_login_token/1 deletes the login_token" do
      login_token = login_token_fixture()
      assert {:ok, %LoginToken{}} = Auth.delete_login_token(login_token)
      assert_raise Ecto.NoResultsError, fn -> Auth.get_login_token!(login_token.id) end
    end

    test "change_login_token/1 returns a login_token changeset" do
      login_token = login_token_fixture()
      assert %Ecto.Changeset{} = Auth.change_login_token(login_token)
    end
  end
end
