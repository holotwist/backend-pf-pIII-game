defmodule RnxServerWeb.Api.FallbackController do
  use RnxServerWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: RnxServerWeb.ChangesetJSON)
    |> render("error.json", changeset: changeset)
  end
end