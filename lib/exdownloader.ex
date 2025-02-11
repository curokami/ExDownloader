defmodule ExDownloader do
  @moduledoc """
  `priv/static/csv` にあるファイルを取得し、ユーザーのホームフォルダ直下の特定のフォルダを優先表示しつつ、保存先を選ばせるモジュール。
  """

  @base_path "priv/static/csv"
  @preferred_folders ["Download", "DeskTop", "Document", "ダウンロード", "デスクトップ", "ドキュメント", "書類"]

  # priv/static/csv 内のファイル一覧を取得する関数
  def list_csv_files do
    case File.ls(@base_path) do
      {:ok, files} ->
        files
        |> Enum.filter(fn file ->
          File.regular?(Path.join(@base_path, file)) and String.ends_with?(file, ".csv")
        end)

      {:error, _} ->
        []
    end
  end

  def get_file(filename) do
    file_path = Path.join(@base_path, filename)

    if File.exists?(file_path) do
      case File.read(file_path) do
        {:ok, content} ->
          save_path = ask_user_for_save_path(filename)

          case save_path do
            {:ok, path} ->
              File.write!(path, content)  # ユーザーが指定した場所に保存
              File.rm(file_path)  # 元ファイルを削除
              {:ok, path}

            {:cancel, _} ->
              {:error, "User canceled the save operation."}
          end

        {:error, reason} ->
          {:error, "Failed to read file: #{inspect(reason)}"}
      end
    else
      {:error, "File not found: #{filename}"}
    end
  end

  defp ask_user_for_save_path(filename) do
    home_dir = System.user_home()

    # ホームディレクトリ直下のフォルダーを取得
    folders =
      case File.ls(home_dir) do
        {:ok, entries} ->
          Enum.filter(entries, &File.dir?(Path.join(home_dir, &1)))
        {:error, _} -> []
      end

    # 優先フォルダーをフィルタリング
    preferred_folders =
      Enum.filter(folders, fn folder ->
        Enum.any?(@preferred_folders, &String.downcase(folder) |> String.contains?(String.downcase(&1)))
      end)

    display_folders = if preferred_folders == [], do: folders, else: preferred_folders

    # フォルダー一覧を表示
    IO.puts("\n保存先を選んでください（番号を入力）:")
    Enum.each(Enum.with_index(display_folders, 1), fn {folder, index} ->
      IO.puts("#{index}: #{folder}")
    end)

    IO.puts("または、以下のフォーマットで入力してください。キャンセルする場合は Enter を押してください。")
    IO.puts("デフォルト: #{home_dir}/")
    IO.write("> #{home_dir}/")

    user_input = IO.gets("") |> String.trim()

    case Integer.parse(user_input) do
      {num, _} when num > 0 and num <= length(display_folders) ->
        selected_folder = Enum.at(display_folders, num - 1)
        {:ok, Path.join([home_dir, selected_folder, filename])}

      _ when user_input == "" ->
        {:cancel, "User canceled"}

      _ ->
        {:ok, Path.join([home_dir, user_input, filename])}
    end
  end
end
