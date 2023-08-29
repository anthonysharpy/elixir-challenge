defmodule Parser do
  @moduledoc """
  Helpers for parsing the request/response pairs.
  """

  @doc """
  Get the URL that represents this request. Also include the request method since
  it's possible an API might use the same URL but with different methods.
  """
  def get_url_for_pair(pair_map) do
    pair_map["request"]["method"] <> " " <> clean_url(pair_map["request"]["url"])
  end

  @doc """
  Match one list of maps with another list of maps where the result
  of extract_key is the same for both maps. Returns a list of tuples.
  The first value of the tuple is a map from list_1; the second value
  is the matching map from the list_2. The second or first element
  of any given tuple might be nil if no match could be found.
  """
  def pair_list_of_maps(list_1, list_2, extract_key_function) do
    # Take all maps from list_1 and match them up with the corresponding
    # map from list_2, if there is one.
    matched_maps = Enum.map(list_1, fn map ->
      corresponding_map = Enum.find(list_2, fn corresponding_map_candidate ->
        extract_key_function.(map) == extract_key_function.(corresponding_map_candidate)
      end)

      {map, corresponding_map}
    end)

    # We also need to include any maps found in list_2 but not list_1.
    matched_maps ++ Enum.reduce(list_2, [], fn map, acc ->
      corresponding_map = Enum.find(list_1, fn corresponding_map_candidate ->
        extract_key_function.(map) == extract_key_function.(corresponding_map_candidate)
      end)

      case corresponding_map do
        nil -> [{nil, map}] ++ acc # We found something that wasn't in the first file, so include it.
        _ -> acc # If there is a match with the first file then we already have it, skip.
      end
    end)
  end

  # Return the URL without any parameters.
  defp clean_url(url) do
    case url do
      nil -> nil
      _ ->
        case String.contains?(url, "?") do
          true -> hd(String.split(url, "?"))
          false -> url
        end
    end
  end

  @doc """
  Uses recursion to return keys from a deeply-nested map.
  Returns a list of all keys. For example, it might return:

  [user.name,
  user.contactInformation.email,
  user.contactInformation.phone]
  """
  def get_keys_from_map(map) do
    case is_map(map) do
      false -> nil
      true ->
        Enum.flat_map(map, fn {k, v} ->
          case is_map(v) do
            true -> get_keys_from_map_with_namespace(v, k)
            false -> [k]
          end
        end)
    end
  end

  def string_to_bool!(string) do
    case string do
      "true" -> true
      "1" -> true
      "false" -> false
      "0" -> false
      _ -> raise "unknown boolean string value #{string}"
    end
  end

  # The same as get_keys_from_map but prepends the results with a string
  # that represents the path of the key (e.g. "user.contactInformation").
  defp get_keys_from_map_with_namespace(map, path) do
    Enum.flat_map(map, fn {k, v} ->
      case is_map(v) do
        true -> get_keys_from_map_with_namespace(v, "#{path}.#{k}")
        false -> ["#{path}.#{k}"]
      end
    end)
  end
end
