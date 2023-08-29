defmodule RequestPairerTest do
  use ExUnit.Case
  doctest RequestPairer

  import ExUnit.CaptureIO

  test "pair_request_maps" do
    file_1_pairs = [
      %{ "request" => %{ "method" => "GET", "url" => "www.test.com/somethingelse" } },
      %{ "request" => %{ "method" => "GET", "url" => "www.test.com" } },
      %{ "request" => %{ "method" => "GET", "url" => "www.test.com/somethingelseentirely" } }
    ]

    file_2_pairs = [
      %{ "request" => %{ "method" => "GET", "url" => "www.test.com" } },
      %{ "request" => %{ "method" => "GET", "url" => "www.test.com/somethingelse" } },
      %{ "request" => %{ "method" => "GET", "url" => "www.test.com/newthing" } }
    ]

    expected_results = [
      { %{ "request" => %{ "method" => "GET", "url" => "www.test.com" } }, %{ "request" => %{ "method" => "GET", "url" => "www.test.com" } }},
      { %{ "request" => %{ "method" => "GET", "url" => "www.test.com/somethingelse" } }, %{ "request" => %{ "method" => "GET", "url" => "www.test.com/somethingelse" } }},
      { %{ "request" => %{ "method" => "GET", "url" => "www.test.com/somethingelseentirely" } }, nil },
      { nil, %{ "request" => %{ "method" => "GET", "url" => "www.test.com/newthing" }} }
    ]

    # Suppress writing anything to console.
    io_output = capture_io(fn ->
      results = RequestPairer.pair_request_maps(file_1_pairs, file_2_pairs, true)

      assert length(results) == length(expected_results)

      Enum.each(expected_results, fn er ->
        assert Enum.any?(results, fn result ->
          result == er
        end)
      end)
    end)

    # Also might as well check that the console output is working properly.
    assert String.contains?(io_output, "One but not both of the files made a request to \"GET www.test.com/newthing\"")
    assert String.contains?(io_output, "One but not both of the files made a request to \"GET www.test.com/somethingelseentirely\"")
  end
end
