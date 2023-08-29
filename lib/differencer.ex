defmodule Differencer do
  @doc """
  Warn where pairs are matched but the URLs are different (i.e. the user
  decided this URL was renamed). Irrelevant if user input is disabled.
  """
  def find_nonmatching_matches(matched_pairs) do
    Enum.each(matched_pairs, fn matched_pair ->
      case matched_pair do
        {_file_1_pair, nil} -> nil
        {nil, _file_2_pair} -> nil
        {file_1_pair, file_2_pair} ->
          file_1_url = Parser.get_url_for_pair(file_1_pair)
          file_2_url = Parser.get_url_for_pair(file_2_pair)

          if file_1_url != file_2_url do
            IO.puts "Critical - URLs have changed between files: #{file_1_url} vs #{file_2_url}"
          end
      end
    end)
  end

  @doc """
  Warn where requests have changed order.
  """
  def check_request_order(matched_pairs, file_1_pairs, file_2_pairs) do
    Enum.each(matched_pairs, fn matched_pair ->
      case matched_pair do
        {_file_1_pair, nil} -> nil
        {nil, _file_2_pair} -> nil
        {file_1_pair, _file_2_pair} ->
          url = Parser.get_url_for_pair(file_1_pair)

          file_1_index = Enum.find_index(file_1_pairs, fn pair ->
            url == Parser.get_url_for_pair(pair)
          end)
          file_2_index = Enum.find_index(file_2_pairs, fn pair ->
            url == Parser.get_url_for_pair(pair)
          end)

          if file_1_index != file_2_index do
            IO.puts "Notice - the order of request #{url} has changed from #{file_1_index} to #{file_2_index}"
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
    Enum.each(matched_pairs, fn matched_pair ->
      {pair_1, pair_2} = matched_pair

      url = case matched_pair do
        {_p1, nil} -> nil
        {nil, _p2} -> nil
        {p1, _p2} -> Parser.get_url_for_pair(p1)
      end

      # If url is nil then it means this request does not exist in both files.
      # Therefore we can't compare responses.
      if url != nil do
        pair_1_response_body = pair_1["response"]["body"]
        pair_2_response_body = pair_2["response"]["body"]

        {result_1, pair_1_response_map} = Jason.decode(pair_1_response_body)
        {result_2, pair_2_response_map} = Jason.decode(pair_2_response_body)

        # Check the first file against the second.
        if result_1 != :error do
          pair_1_response_keys = Parser.get_keys_from_map(pair_1_response_map)

          case result_2 do
            :error ->
              Enum.each(pair_1_response_keys, fn key ->
                IO.puts "Info - request #{url} in file 1 returned key #{key} in the response body, but in file 2 it didn't"
              end)
            :ok ->
              pair_2_response_keys = Parser.get_keys_from_map(pair_2_response_map)

              Enum.each(pair_1_response_keys, fn key ->
                case Enum.any?(pair_2_response_keys, fn other_key -> other_key == key end) do
                  true -> nil
                  false -> IO.puts "Info - request #{url} in file 1 returned key #{key} in the response body, but in file 2 it didn't"
                end
              end)
          end
        end

        # Check the second file against the first.
        if result_2 != :error do
          pair_2_response_keys = Parser.get_keys_from_map(pair_2_response_map)

          case result_1 do
            :error ->
              Enum.each(pair_2_response_keys, fn key ->
                IO.puts "Info - request #{url} in file 2 returned key #{key} in the response body, but in file 1 it didn't"
              end)
            :ok ->
              Enum.each(pair_2_response_keys, fn key ->
                pair_1_response_keys = Parser.get_keys_from_map(pair_1_response_map)

                case Enum.any?(pair_1_response_keys, fn other_key -> other_key == key end) do
                  true -> nil
                  false -> IO.puts "Info - request #{url} in file 2 returned key #{key} in the response body, but in file 1 it didn't"
                end
              end)
          end
        end
      end
    end)
  end

  @doc """
  Warn where the order of the request headers have changed (or a request header
  has been added/removed).
  """
  def check_request_headers(matched_pairs) do
    Enum.each(matched_pairs, fn matched_pair ->
      {pair_1, pair_2} = matched_pair

      url = case matched_pair do
        {_p1, nil} -> nil
        {nil, _p2} -> nil
        {p1, _p2} -> Parser.get_url_for_pair(p1)
      end

      # If url is nil then it means this request does not exist in both files.
      # Therefore we can't compare headers.
      if url != nil do
        pair_1_request_headers = pair_1["request"]["headers"]
        pair_2_request_headers = pair_2["request"]["headers"]

        matched_headers = Parser.pair_list_of_maps(pair_1_request_headers,
          pair_2_request_headers,
          fn map -> map["name"] end )

        # Warn about removed/added headers.
        Enum.each(matched_headers, fn header_tuple ->
          case header_tuple do
            {h1, nil} -> IO.puts "Warning - file 1 - request #{url} had request header #{h1["name"]} but file 2 did not"
            {nil, h2} -> IO.puts "Warning - file 2 - request #{url} had request header #{h2["name"]} but file 1 did not"
            _ -> nil
          end
        end)

        # Warn about headers changing order.
        Enum.each(matched_headers, fn header_tuple ->
          case header_tuple do
            {_h1, nil} -> nil # They didn't change order if they only exist in one file.
            {nil, _h2} -> nil
            {h1, h2} ->
              h1_index = Enum.find_index(pair_1_request_headers, fn x -> x["name"] == h1["name"] end) + 1
              h2_index = Enum.find_index(pair_2_request_headers, fn x -> x["name"] == h2["name"] end) + 1

              if h1_index != h2_index do
                IO.puts "Notice - request header #{h1["name"]} moved from position #{h1_index} to #{h2_index} in request #{url}"
              end
          end
        end)
      end
    end)
  end

  @doc """
  Warn where one file makes a request that the other one doesn't.
  """
  def find_failed_matches(matched_pairs) do
    Enum.each(matched_pairs, fn matched_pair ->
      case matched_pair do
        {file_1_pair, nil} ->
          IO.puts "Warning - file 1 made a request to #{Parser.get_url_for_pair(file_1_pair)} but file 2 did not"
        {nil, file_2_pair} ->
          IO.puts "Warning - file 2 made a request to #{Parser.get_url_for_pair(file_2_pair)} but file 1 did not"
        _ -> nil
      end
    end)
  end
end
