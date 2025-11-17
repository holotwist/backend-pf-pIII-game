defmodule RnxServer.AuthFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `RnxServer.Auth` context.
  """

  @doc """
  Generate a unique login_token token.
  """
  def unique_login_token_token, do: "some token#{System.unique_integer([:positive])}"

  @doc """
  Generate a login_token.
  """
  def login_token_fixture(attrs \\ %{}) do
    {:ok, login_token} =
      attrs
      |> Enum.into(%{
        expires_at: ~U[2025-11-11 15:40:00Z],
        token: unique_login_token_token()
      })
      |> RnxServer.Auth.create_login_token()

    login_token
  end
end
