defmodule RnxServer.Songs.Analyzer do
  @modledoc """
  Analyzes beatmap files to calculate difficulty metrics.
  Now supports legacy .osu (game1) and new level_v2.json (game2) formats.
  """

  require Logger

  # Mapeamos cada dirección a un ángulo en grados para calcular la distancia de giro.
  @angle_map %{
    "up" => 135,
    "left" => 45,
    "down" => -45,
    "right" => -135
  }

  @spec calculate_details(String.t(), String.t()) ::
          %{lv_number: float(), complexity: String.t(), notes_number: integer(), notes_data: list()} | nil
  def calculate_details(song_path, game_mode) do
    case parse_notes(song_path, game_mode) do
      {:ok, notes_data} ->
        # --- Procesar notas "trick" si es game2 ---
        processed_notes_data = 
          if game_mode == "game2" do
            all_directions = ["up", "down", "left", "right"]
            
            Enum.map(notes_data, fn note ->
              # El tipo de nota viene como string "type" del JSON.
              if note["type"] == "trick" do
                initial_direction = note["initial_direction"]
                # Elegir una dirección final aleatoria que no sea la inicial
                possible_final_dirs = all_directions -- [initial_direction]
                final_direction = Enum.random(possible_final_dirs)
                # Añadimos la nueva clave al mapa de la nota
                Map.put(note, "final_direction", final_direction)
              else
                # Si no es una nota "trick", la devolvemos sin cambios
                note
              end
            end)
          else
            # Para game1, las notas no necesitan este procesamiento
            notes_data
          end

        notes_number = Enum.count(processed_notes_data)
        lv_number = calculate_lv_number(processed_notes_data, game_mode)
        complexity = determine_complexity(lv_number)

        %{
          lv_number: lv_number,
          complexity: complexity,
          notes_number: notes_number,
          # --- Devolvemos las notas ya procesadas ---
          notes_data: processed_notes_data
        }

      {:error, reason} ->
        Logger.warning("Could not analyze chart for #{song_path}: #{reason}")
        nil
    end
  end

  # --- Ahora `parse_notes` para game2 espera la ruta al JSON ---
  defp parse_notes(path, "game1") do
    # Lógica para game1 no cambia: busca el .osu en la carpeta.
    case Path.wildcard(Path.join(path, "*.osu")) do
      [osu_path] ->
        with {:ok, content} <- File.read(osu_path),
             {:ok, notes} <- do_parse_osu(content) do
          {:ok, notes}
        end

      [] ->
        {:error, ".osu file not found"}

      _ ->
        {:error, "multiple .osu files found"}
    end
  end

  defp parse_notes(json_path, "game2") do
    # Lógica para game2 ahora parsea el archivo JSON v2.
    with true <- File.exists?(json_path),
         {:ok, body} <- File.read(json_path),
         {:ok, data} <- Jason.decode(body) do
      # --- Ya no convertimos el tiempo aquí, pasamos el mapa completo ---
      notes = Map.get(data, "events", %{}) |> Map.get("notes", [])
      {:ok, notes}
    else
      _ -> {:error, "failed to read or parse level_v2.json"}
    end
  end

  # --- Lógica de parseo de .osu (sin cambios) ---
  defp do_parse_osu(content) do
    notes =
      content
      |> String.split("\n")
      |> Enum.drop_while(fn line -> String.trim(line) != "[HitObjects]" end)
      |> Enum.drop(1)
      |> Enum.map(&String.split(&1, ","))
      |> Enum.filter(fn parts -> length(parts) >= 4 end)
      |> Enum.map(fn parts ->
        %{time: String.to_integer(Enum.at(parts, 2)), column: String.to_integer(Enum.at(parts, 0))}
      end)

    {:ok, notes}
  end

  # --- El dispatcher de cálculo de dificultad ---
  # --- Ahora pasamos el mapa completo de la nota a la función de cálculo ---
  defp calculate_lv_number(notes, "game1"), do: _calculate_lv_game1(Enum.map(notes, & &1.time))
  defp calculate_lv_number(notes, "game2"), do: _calculate_lv_game2(notes)
  defp calculate_lv_number(_, _), do: 0.0

  # --- Lógica de cálculo de game1 (extraída a su propia función y modificada para recibir solo tiempos) ---
  defp _calculate_lv_game1(note_times) do
    if Enum.empty?(note_times) do
      0.0
    else
      sorted_times = Enum.sort(note_times)

      deltas =
        Enum.zip(sorted_times, Enum.drop(sorted_times, 1))
        |> Enum.map(fn {t1, t2} -> max(t2 - t1, 1) end)

      difficulty_sum =
        Enum.reduce(deltas, 0.0, fn delta, acc ->
          base_difficulty = 1000.0 / delta
          burst_multiplier = if delta < 120, do: 1.5, else: 1.0
          acc + (base_difficulty * burst_multiplier)
        end)

      scaling_factor = 0.15
      raw_rating = (difficulty_sum / length(note_times)) * scaling_factor
      Float.round(raw_rating, 2)
    end
  end

  # --- Lógica de cálculo de dificultad mejorada para game2 ---
  # --- La función ahora espera el mapa completo para acceder a "direction" ---
  defp _calculate_lv_game2(notes) do
    if Enum.count(notes) < 2 do
      0.0
    else
      # --- Ordenamos por el campo "time" del mapa ---
      sorted_notes = Enum.sort_by(notes, & &1["time"])

      # Calculamos la "intensidad de movimiento" para cada par de notas consecutivas.
      movement_intensities =
        Enum.zip(sorted_notes, Enum.drop(sorted_notes, 1))
        |> Enum.map(fn {note1, note2} ->
          time_delta = max(round((note2["time"] - note1["time"]) * 1000), 10) # Convertimos a ms y evitamos división por cero
          
          # --- Usamos la dirección final si es una nota "trick" ---
          dir1 = note1["final_direction"] || note1["direction"]
          dir2 = note2["final_direction"] || note2["direction"]

          angle1 = @angle_map[dir1]
          angle2 = @angle_map[dir2]

          # Calcula la distancia angular más corta (ej: 90, 180 grados)
          angle_delta =
            180 - abs(abs(angle1 - angle2) - 180)

          # La dificultad es proporcional a la distancia de giro e inversamente proporcional al tiempo.
          # Se aplica un exponente para penalizar más los movimientos rápidos y largos.
          movement_difficulty = (angle_delta / 180) * (500 / time_delta)
          :math.pow(movement_difficulty, 1.2)
        end)

      # La dificultad total es la media de las intensidades, con un factor de escala.
      total_intensity = Enum.sum(movement_intensities)
      scaling_factor = 2.5 # Este valor se puede ajustar para balancear la dificultad general.

      raw_rating = (total_intensity / Enum.count(movement_intensities)) * scaling_factor
      Float.round(raw_rating, 2)
    end
  end

  # --- Lógica de complejidad ---
  defp determine_complexity(lv_number) do
    cond do
      lv_number < 2.0 -> "Easy"
      lv_number < 4.0 -> "Normal"
      lv_number < 6.5 -> "Hard"
      true -> "Complex"
    end
  end
end