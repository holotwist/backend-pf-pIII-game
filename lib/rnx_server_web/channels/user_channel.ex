defmodule RnxServerWeb.UserChannel do
  use RnxServerWeb, :channel
  require Logger

  @impl true
  def join("user:" <> versioned_user_id, _payload, socket) do
    # `versioned_user_id` llegará como "2.0". Lo dividimos por el "."
    # y nos quedamos con la primera parte ("2") para la comparación.
    # Esto hace que el canal sea compatible con el cliente Godot que usa vsn=2.0.0.
    [requested_user_id | _] = String.split(versioned_user_id, ".")

    # Medida de seguridad:
    # Nos aseguramos de que el usuario que intenta unirse al canal "user:2"
    # sea realmente el usuario con id 2 autenticado en el socket.
    current_user_id = socket.assigns.current_user_id

    # La comparación ahora será "2" == "2", lo cual resultará en `true`.
    if to_string(current_user_id) == requested_user_id do
      Logger.info("User ##{current_user_id} successfully joined their private channel.")
      {:ok, socket}
    else
      Logger.warning(
        "User ##{current_user_id} tried to join unauthorized channel user:#{versioned_user_id}."
      )

      {:error, %{reason: "unauthorized"}}
    end
  end
end