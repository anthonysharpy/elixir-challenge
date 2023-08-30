defmodule Differencer do
  @doc """
  Warn where pairs are matched but the URLs are different (i.e. the user
  decided this URL was renamed). Irrelevant if user input is disabled.
  """
  def find_nonmatching_matches(matched_pairs) do
    Enum.reduce(matched_pairs, [], fn matched_pair, acc ->
      case matched_pair do
        {_file_1_pair, nil} -> acc
        {nil, _file_2_pair} -> acc
        {file_1_pair, file_2_pair} ->
          file_1_url = Parser.get_url_for_pair(file_1_pair)
          file_2_url = Parser.get_url_for_pair(file_2_pair)

          case file_1_url != file_2_url do
            true -> ["Critical - URLs have changed between files: #{file_1_url} vs #{file_2_url}" | acc]
            false -> acc
          end
      end
    end)
  end

  @doc """
  Warn where requests have changed order.
  """
  def check_request_order(matched_pairs, file_1_pairs, file_2_pairs) do
    Enum.reduce(matched_pairs, [], fn matched_pair, acc ->
      case matched_pair do
        {_file_1_pair, nil} -> acc
        {nil, _file_2_pair} -> acc
        {file_1_pair, _file_2_pair} ->
          url = Parser.get_url_for_pair(file_1_pair)

          file_1_index = Enum.find_index(file_1_pairs, fn pair ->
            url == Parser.get_url_for_pair(pair)
          end) || 0
          file_2_index = Enum.find_index(file_2_pairs, fn pair ->
            url == Parser.get_url_for_pair(pair)
          end) || 0

          case file_1_index != file_2_index do
            true -> ["Notice - the order of request #{url} has changed from #{file_1_index+1} to #{file_2_index+1}" | acc]
            false -> acc
          end
      end
    end)
  end

  @doc """
  Print a notice where key has been added or removed from the response body.
  In theory this is irrelevant since what the the response says makes no difference.
  However, we do this because if new data is being returned that is required to
  carry out subsequent requests, that is useful information to a developer.
  """
  def check_response_body_keys(matched_pairs) do
    Enum.reduce(matched_pairs, [], fn matched_pair, acc ->
      {pair_1, pair_2} = matched_pair

      url = case matched_pair do
        {_p1, nil} -> nil
        {nil, _p2} -> nil
        {p1, _p2} -> Parser.get_url_for_pair(p1)
      end

      # If url is nil then it means this request does not exist in both files.
      # Therefore we can't compare responses.
      case url != nil do
        true ->
          pair_1_response_body = pair_1["response"]["body"]
          pair_2_response_body = pair_2["response"]["body"]

          {pair_1_decode_success, pair_1_response_map} = Jason.decode(pair_1_response_body)
          {pair_2_decode_success, pair_2_response_map} = Jason.decode(pair_2_response_body)

          # Check the first file against the second.
          acc = acc ++ case pair_1_decode_success != :error do
            true -> compare_response_body_keys(pair_1_response_map, pair_2_response_map, pair_2_decode_success, url, 1, 2)
            false -> []
          end

          # Check the second file against the first.
          acc ++ case pair_2_decode_success != :error do
            true -> compare_response_body_keys(pair_2_response_map, pair_1_response_map, pair_1_decode_success, url, 2, 1)
            false -> []
          end
        false ->
          acc
      end
    end)
  end

  # Helper function for check_response_body_keys.
  defp compare_response_body_keys(pair_1_map, pair_2_map, pair_2_decode_success, url, file_number, other_file_number) do
    pair_1_response_keys = Parser.get_keys_from_map(pair_1_map)

    case pair_2_decode_success do
      :error -> # If pair 2 failed to decode then we just spit out all the keys from pair 1.
        Enum.map(pair_1_response_keys, fn key ->
          "Info - request #{url} in file #{file_number} returned key #{key} in the response body, but in file #{other_file_number} it didn't"
        end)
      :ok ->
        pair_2_response_keys = Parser.get_keys_from_map(pair_2_map)

        Enum.reduce(pair_1_response_keys, [], fn key, acc ->
          case Enum.any?(pair_2_response_keys, fn other_key -> other_key == key end) do
            true -> acc
            false -> ["Info - request #{url} in file #{file_number} returned key #{key} in the response body, but in file #{other_file_number} it didn't" | acc]
          end
        end)
    end
  end

  @doc """
  Warn where the order of the request headers have changed (or a request header
  has been added/removed).
  """
  def check_request_headers(matched_pairs) do
    Enum.reduce(matched_pairs, [], fn matched_pair, acc ->
      {pair_1, pair_2} = matched_pair

      url = case matched_pair do
        {_p1, nil} -> nil
        {nil, _p2} -> nil
        {p1, _p2} -> Parser.get_url_for_pair(p1)
      end

      # If url is nil then it means this request does not exist in both files.
      # Therefore we can't compare headers.
      case url != nil do
        true ->
          pair_1_request_headers = pair_1["request"]["headers"]
          pair_2_request_headers = pair_2["request"]["headers"]

          # Match headers on the "name" field.
          matched_headers = Parser.pair_list_of_maps(pair_1_request_headers,
            pair_2_request_headers,
            fn map -> map["name"] end )

          acc ++
            check_removed_added_headers(matched_headers, url) ++
            check_header_order(matched_headers, url, pair_1_request_headers, pair_2_request_headers)
        false ->
          acc
      end
    end)
  end

  # Helper function for check_request_headers.
  defp check_header_order(matched_headers, url, pair_1_request_headers, pair_2_request_headers) do
    Enum.reduce(matched_headers, [], fn header_tuple, acc ->
      case header_tuple do
        {_h1, nil} -> acc # They didn't change order if they only exist in one file.
        {nil, _h2} -> acc
        {h1, h2} ->
          h1_index = Enum.find_index(pair_1_request_headers, fn x -> x["name"] == h1["name"] end) || 0
          h2_index = Enum.find_index(pair_2_request_headers, fn x -> x["name"] == h2["name"] end) || 0

          case h1_index != h2_index do
            true -> ["Notice - request header #{h1["name"]} moved from position #{h1_index+1} to #{h2_index+1} in request #{url}" | acc]
            false -> acc
          end
      end
    end)
  end

  # Helper function for check_request_headers.
  defp check_removed_added_headers(matched_headers, url) do
    Enum.reduce(matched_headers, [], fn header_tuple, acc ->
      case header_tuple do
        {h1, nil} -> ["Warning - file 1 - request #{url} had request header #{h1["name"]} but file 2 did not" | acc]
        {nil, h2} -> ["Warning - file 2 - request #{url} had request header #{h2["name"]} but file 1 did not" | acc]
        _ -> acc
      end
    end)
  end

  @doc """
  Warn where one file makes a request that the other one doesn't.
  """
  def find_failed_matches(matched_pairs) do
    Enum.reduce(matched_pairs, [], fn matched_pair, acc ->
      case matched_pair do
        {file_1_pair, nil} ->
          ["Warning - file 1 made a request to #{Parser.get_url_for_pair(file_1_pair)} but file 2 did not" | acc]
        {nil, file_2_pair} ->
          ["Warning - file 2 made a request to #{Parser.get_url_for_pair(file_2_pair)} but file 1 did not" | acc]
        _ -> acc
      end
    end)
  end
end
