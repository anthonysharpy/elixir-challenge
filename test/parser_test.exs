defmodule ParserTest do
  use ExUnit.Case
  doctest Parser

  test "string_to_bool!" do
    test_table = [
      {"true", true},
      {"false", false},
      {"1", true},
      {"0", false},
    ]

    Enum.each(test_table, fn {input, expected_output} ->
      assert Parser.string_to_bool!(input) == expected_output
    end)
  end

  test "get_url_for_pair" do
    test_table = [
      {%{ "request" => %{ "method" => "GET", "url" => "www.test.com" } }, "GET www.test.com"},
      {%{ "request" => %{ "method" => "GET", "url" => "www.test.com?ignorethis" } }, "GET www.test.com"},
      {%{ "request" => %{ "method" => "POST", "url" => "www.test.com" } }, "POST www.test.com"},
    ]

    Enum.each(test_table, fn {input, expected_output} ->
      assert Parser.get_url_for_pair(input) == expected_output
    end)
  end

  test "get_keys_from_map" do
    map = %{
      "request" => %{
        "method" => "GET",
        "url" => "www.test.com"
      },
      "body" => %{
        "user" => %{
          "name" => "Test User",
          "age" => 99,
          "address" => %{
            "line1" => "Test House",
            "line2" => "Test Road"
          }
        }
      }
    }

    expected_keys = [
      "request.method",
      "request.url",
      "body.user.name",
      "body.user.age",
      "body.user.address.line1",
      "body.user.address.line2"
    ]

    results = Parser.get_keys_from_map(map)

    assert length(expected_keys) == length(results)

    Enum.each(expected_keys, fn key ->
      assert Enum.any?(results, fn result ->
        key == result
      end)
    end)
  end

  test "pair_list_of_maps" do
    list_1 = [
      %{ "id" => "1" },
      %{ "id" => "2" },
      %{ "id" => "3" },
    ]

    list_2 = [
      %{ "id" => "2" },
      %{ "id" => "3" },
      %{ "id" => "4" },
    ]

    expected_results = [
      {%{ "id" => "1" }, nil},
      {%{ "id" => "2" }, %{ "id" => "2" }},
      {%{ "id" => "3" }, %{ "id" => "3" }},
      {nil, %{ "id" => "4" }}
    ]

    results = Parser.pair_list_of_maps(list_1, list_2, fn map ->
      map["id"]
    end)

    assert length(expected_results) == length(results)

    Enum.each(expected_results, fn er ->
      assert Enum.any?(results, fn r ->
        er == r
      end)
    end)
  end
end
