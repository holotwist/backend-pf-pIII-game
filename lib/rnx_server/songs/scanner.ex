defmodule RnxServer.Songs.Scanner do
  use GenServer
  alias RnxServer.Songs.Analyzer
  require Logger

  @levels_path "levels"

  # --- Client API ---
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_random_song(game_mode) do
    GenServer.call(__MODULE__, {:get_random_song, game_mode})
  end

  def get_all_songs(game_mode) do
    GenServer.call(__MODULE__, {:get_all_songs, game_mode})
  end

  # --- Server Callbacks ---
  @impl true
  def init(_opts) do
    Logger.info("Starting Song Scanner...")
    state = scan_songs()
    {:ok, state}
  end

  @impl true
  def handle_call({:get_random_song, game_mode}, _from, state) do
    songs_for_mode = Map.get(state, game_mode, [])
    if Enum.empty?(songs_for_mode), do: {:reply, nil, state}, else: {:reply, Enum.random(songs_for_mode), state}
  end

  @impl true
  def handle_call({:get_all_songs, game_mode}, _from, state) do
    {:reply, Map.get(state, game_mode, []), state}
  end

  # --- Internal Logic ---
  defp scan_songs() do
    songs =
      for game_mode <- ["game1", "game2"], reduce: %{} do
        acc ->
          mode_path = Path.join(@levels_path, game_mode)
          
          songs_in_mode =
            case File.ls(mode_path) do
              {:ok, song_folders} ->
                song_folders
                |> Enum.map(&Path.join(mode_path, &1))
                |> Enum.filter(&File.dir?/1)
                |> Enum.map(&process_song_folder(&1, game_mode))
                |> Enum.reject(&is_nil/1)
              {:error, _} -> []
            end
          
          Map.put(acc, game_mode, songs_in_mode)
      end
      
    Logger.info("Song scan complete. Found #{Enum.sum(for {_, v} <- songs, do: Enum.count(v))} songs.")
    songs
  end

  # --- Dispatcher para procesar carpetas de canciones ---
  # Elige qué hacer basado en el modo de juego.
  defp process_song_folder(song_path, "game1") do
    # game1 usa la lógica legacy: analiza la carpeta en busca de un .osu
    metadata_path = Path.join(song_path, "level.json")
    analyze_and_build_song_map(song_path, metadata_path, "game1")
  end

  defp process_song_folder(song_path, "game2") do
    # game2 usa la nueva lógica: analiza directamente el archivo level_v2.json
    v2_chart_path = Path.join(song_path, "level_v2.json")
    analyze_and_build_song_map(v2_chart_path, v2_chart_path, "game2")
  end

  # --- Función unificada para construir el mapa de la canción ---
  # `path_to_analyze` puede ser una carpeta (game1) o un archivo (game2).
  # `metadata_path` es siempre el archivo JSON que contiene la info base.
  defp analyze_and_build_song_map(path_to_analyze, metadata_path, game_mode) do
    # Usamos un `with` externo para manejar la lectura del archivo y el parseo del JSON.
    with true <- File.exists?(metadata_path),
         {:ok, body} <- File.read(metadata_path),
         {:ok, decoded_json} <- Jason.decode(body) do

      # 1. Determinamos dónde buscar los metadatos basados en el game_mode.
      core_metadata =
        case game_mode do
          "game2" -> Map.get(decoded_json, "metadata")
          _ -> decoded_json # Para "game1", los metadatos están en el nivel superior.
        end

      # 2. Usamos un `with` interno para trabajar con los metadatos extraídos.
      #    El `%{}` asegura que solo continuamos si `core_metadata` es un mapa válido.
      with %{} = core_metadata,
           audio_filename <- Map.get(core_metadata, "audioFile") || Map.get(core_metadata, "audio_file"),
           true <- not is_nil(audio_filename),
           %{} = analysis_data <- Analyzer.calculate_details(path_to_analyze, game_mode) do

        # Si llegamos aquí, todas las variables son seguras de usar.
        song_folder_name = Path.basename(Path.dirname(metadata_path))
        encoded_folder_name = URI.encode(song_folder_name)
        base_path = "/" <> Path.join(["levels", game_mode, encoded_folder_name])

        encoded_audio_filename = URI.encode(audio_filename)

        core_metadata
        |> Map.merge(analysis_data)
        |> Map.merge(%{
          "game_mode" => game_mode,
          "level_folder" => song_folder_name,
          "cover_url" => base_path <> "/cover.jpg",
          "audio_url" => base_path <> "/" <> encoded_audio_filename
        })
      else
        # Si cualquier paso del `with` interno falla (falta mapa, falta audio, etc.), se ejecuta esto.
        _ ->
          Logger.warning("Could not parse or analyze song resource (missing data or invalid format): #{path_to_analyze}")
          nil
      end
    else
      # Si la lectura o el parseo del JSON falla, se ejecuta esto.
      _ ->
        Logger.warning("Could not read or decode JSON file: #{metadata_path}")
        nil
    end
  end
end