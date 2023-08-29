defmodule RequestPairer do
  @doc """
  Match requests/responses pairs from file_1_pairs with pairs from file_2_pairs.
  Returns a list of tuples. The first value of the tuple is the pair
  from the first file; the second value is the pair from the second.
  The second or first element of any given tuple might be nil if no
  pairing could be found.
  Pairs are matched based on the request method and URL.
  """
  def pair_request_maps(file_1_pairs, file_2_pairs, no_input_mode) do
    # Take all pairs from file 1 and match them up with the corresponding
    # pair from file 2, if there is one.
    matched_pairs = Enum.map(file_1_pairs, fn pair_map ->
      url = Parser.get_url_for_pair(pair_map)
      {pair_map, get_corresponding_entry_for_url(url, file_2_pairs, no_input_mode)}
    end)

    # We also need to include any pairs found in file 2 but not file 1.
    matched_pairs ++ Enum.reduce(file_2_pairs, [], fn pair_map, acc ->
      url = Parser.get_url_for_pair(pair_map)

      case get_corresponding_entry_for_url(url, file_1_pairs, no_input_mode) do
        nil -> [{nil, pair_map}] ++ acc # We found something that wasn't in the first file, so include it.
        _ -> acc # If there is a match with the first file then we already have it, skip.
      end
    end)
  end

  # Return the pair from file_pairs that corresponds to the given URL. If
  # no pair can be found, prompt the user for confirmation (the URL might
  # have changed). If the user confirms there is no entry, nil is returned.
  defp get_corresponding_entry_for_url(url, file_pairs, no_input_mode) do
    entry = Enum.find(file_pairs, fn pair_map ->
      Parser.get_url_for_pair(pair_map) == url
    end)

    case entry do
      nil -> user_choose_entry(url, file_pairs, no_input_mode)
      _ -> entry
    end
  end

  # We couldn't figure out which entry matched the URL, so let the user choose.
  defp user_choose_entry(url, file_pairs, no_input_mode) do
    IO.puts "One but not both of the files made a request to \"#{url}\". This indicates " <>
     "endpoints have changed. It might have been renamed; please see below if any of the URLs "<>
     "from the other file match this URL. Choose \"None\" if none of them match " <>
     "(i.e. it's a newly added/removed endpoint)."

    urls = Enum.map(file_pairs, fn pair_map ->
      Parser.get_url_for_pair(pair_map)
    end)

    IO.puts "0. None"

    Enum.with_index(urls, 1) |> Enum.each(fn {cleaned_url, index} ->
      IO.puts "#{index}. #{cleaned_url}"
    end)

    case no_input_mode do
      true -> nil
      false ->
        case IO.gets("Which URL matches the original URL? ") do
          "0\n" -> nil
          input ->
            case Integer.parse(input) do
              {input_as_number, _} -> Enum.at(file_pairs, input_as_number-1)
              _ ->
                IO.puts "Invalid input, please try again."
                user_choose_entry(url, file_pairs, false)
            end
        end
    end
  end
end
