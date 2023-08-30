defmodule HTTPComparer.Application do
  use Application
  @moduledoc """
  HTTPComparer compares two files, each containing JSON representations of a list of request and response pairs.
  """

  def start(_type, _args) do
    {:ok, self()}
  end

  def main() do
    application(Enum.at(System.argv(), 0), Enum.at(System.argv(), 1), Parser.string_to_bool!(Enum.at(System.argv(), 2)))
  end

  def application(file_1_path, file_2_path, no_input_mode) do
    IO.puts "Opening files..."
    {file_1_contents, file_2_contents} = fetch_files!(file_1_path, file_2_path)
    IO.puts "Files opened successfully..."

    # Each file is essentially a list of request/response "pairs".
    # First, decode the JSON files so we can easily traverse them.
    # We will get a list of maps (each list being a request/response pair).
    {file_1_pairs, file_2_pairs} = decode_json!(file_1_contents, file_2_contents)

    # It's possible that the data might have duplicate requests (e.g. from trying
    # to login twice). If this happens it might mess up the pairing, so we
    # detect and warn about it.
    duplicate_warnings = check_for_duplicates(file_1_pairs) ++ check_for_duplicates(file_2_pairs)
    print_string_list(duplicate_warnings)

    # Match-up pairs from the first file with pairs from the second file.
    matched_pairs = RequestPairer.pair_request_maps(file_1_pairs, file_2_pairs, no_input_mode)

    IO.puts "Finding differences in files..."
    duplicate_warnings ++ find_differences(file_1_pairs, file_2_pairs, matched_pairs)
  end

  defp fetch_files!(file_1_path, file_2_path) do
    file_1_result = File.read(file_1_path)
    file_2_result = File.read(file_2_path)

    case file_1_result do
      {:error, reason} -> raise "failed to open file 1: #{reason}"
      _ ->
        case file_2_result do
          {:error, reason} -> raise "failed to open file 2: #{reason}"
          _ ->  {elem(file_1_result, 1), elem(file_2_result, 1)}
        end
    end
  end

  defp print_string_list(list) do
    Enum.each(list, fn item ->
      IO.puts item
    end)
  end

  # Returns a list of strings containing the output, so this could be routed
  # into a web page or something like that. For demonstration purposes, we also
  # print the output directly to console.
  defp find_differences(file_1_pairs, file_2_pairs, matched_pairs) do
    IO.puts "======================================"
    IO.puts "               Requests"
    IO.puts "======================================"

    requests_output = Differencer.find_nonmatching_matches(matched_pairs) ++
      Differencer.find_failed_matches(matched_pairs) ++
      Differencer.check_request_order(matched_pairs, file_1_pairs, file_2_pairs)
    print_string_list(requests_output)

    IO.puts "======================================"
    IO.puts "               Headers"
    IO.puts "======================================"

    headers_output = Differencer.check_request_headers(matched_pairs)
    print_string_list(headers_output)

    IO.puts "======================================"
    IO.puts "               Response"
    IO.puts "======================================"

    response_output = Differencer.check_response_body_keys(matched_pairs)
    print_string_list(response_output)

    IO.puts "======================================"

    requests_output ++ headers_output ++ response_output
  end

  # Warn if there are any duplicate requests in the same file.
  defp check_for_duplicates(pairs_list) do
    Enum.reduce(pairs_list, [], fn pair, acc ->
      url = Parser.get_url_for_pair(pair)

      occurances = Enum.count(pairs_list, fn other_pair ->
        Parser.get_url_for_pair(other_pair) == url
      end)

      case occurances > 1 do
        true -> ["Critical - request #{url} appears more than once in the same file; results will be inaccurate" | acc]
        false -> acc
      end
    end)
  end

  defp decode_json!(file_1, file_2) do
    file_1_decode_result = Jason.decode(file_1)
    file_2_decode_result = Jason.decode(file_2)

    case file_1_decode_result do
      {:error, reason} -> raise "invalid JSON in file_1: #{reason}"
      _ -> nil
    end

    case file_2_decode_result do
      {:error, reason} -> raise "invalid JSON in file_2: #{reason}"
      _ -> nil
    end

    {elem(file_1_decode_result, 1), elem(file_2_decode_result, 1)}
  end
end
