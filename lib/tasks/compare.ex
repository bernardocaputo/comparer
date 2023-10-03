defmodule Mix.Tasks.Compare do
  use Mix.Task

  alias Comparer

  def run(arg) do
    with {:ok, old_version_path, new_version_path} <- parse_cli_argument(arg),
         {:ok, old_version_json} <- file_read_and_decode(old_version_path),
         {:ok, new_version_json} <- file_read_and_decode(new_version_path),
         result <- Comparer.compare_versions(old_version_json, new_version_json),
         {:ok, encoded_result} <- Jason.encode(result),
         path <- "./result.json",
         :ok <- File.write(path, encoded_result) do
      IO.puts("result at: #{path}")
    end
  end

  defp parse_cli_argument(arg) do
    case OptionParser.parse(arg, strict: [old_version_path: :string, new_version_path: :string]) do
      {[old_version_path: old, new_version_path: new], _, _} ->
        {:ok, old, new}

      error ->
        error |> IO.inspect()

        IO.inspect(
          "old-version-path and new-version-path are mandatory arguments. ex: mix compare --old-version-path ~/path/to/file.json --new-version-path ~path/to/file_new.json"
        )
    end
  end

  def file_read_and_decode(path) do
    case File.read(path) do
      {:ok, string} -> Jason.decode(string)
      {:error, reason} -> :file.format_error(reason)
    end
  end
end
