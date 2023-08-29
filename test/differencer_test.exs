defmodule DifferencerTest do
  use ExUnit.Case
  doctest Differencer

  import ExUnit.CaptureIO

  test "check_request_order" do
    # This is really ugly but I don't think putting it in a file is really any better.
    test_table = [
      {
        [
          {
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com" },
            },
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com" },
            }
          },
          {
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com/somethingelse" },
            },
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com/somethingelse" },
            }
          }
        ],
        [
          %{
            "request" => %{ "method" => "GET", "url" => "www.test.com" },
          },
          %{
            "request" => %{ "method" => "GET", "url" => "www.test.com/somethingelse" },
          }
        ],
        [
          %{
            "request" => %{ "method" => "GET", "url" => "www.test.com/somethingelse" },
          },
          %{
            "request" => %{ "method" => "GET", "url" => "www.test.com" },
          }
        ],
        [
          "Notice - the order of request GET www.test.com has changed from 0 to 1",
          "Notice - the order of request GET www.test.com/somethingelse has changed from 1 to 0"
        ]
      },

      {
        [
          {
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com" },
            },
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com" },
            }
          },
          {
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com/somethingelse" },
            },
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com/somethingelse" },
            }
          }
        ],
        [
          %{
            "request" => %{ "method" => "GET", "url" => "www.test.com/somethingelse" },
          },
          %{
            "request" => %{ "method" => "GET", "url" => "www.test.com" },
          }
        ],
        [
          %{
            "request" => %{ "method" => "GET", "url" => "www.test.com" },
          },
          %{
            "request" => %{ "method" => "GET", "url" => "www.test.com/somethingelse" },
          }
        ],
        [
          "Notice - the order of request GET www.test.com has changed from 1 to 0",
          "Notice - the order of request GET www.test.com/somethingelse has changed from 0 to 1"
        ]
      },

      {
        [
          {
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com" },
            },
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com" },
            }
          },
          {
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com/somethingelse" },
            },
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com/somethingelse" },
            }
          }
        ],
        [
          %{
            "request" => %{ "method" => "GET", "url" => "www.test.com" },
          },
          %{
            "request" => %{ "method" => "GET", "url" => "www.test.com/somethingelse" },
          }
        ],
        [
          %{
            "request" => %{ "method" => "GET", "url" => "www.test.com" },
          },
          %{
            "request" => %{ "method" => "GET", "url" => "www.test.com/somethingelse" },
          }
        ],
        [
          nil
        ]
      },
    ]

    Enum.each(test_table, fn {matched_pairs, file_1_pairs, file_2_pairs, expected_output} ->
      output = capture_io(fn ->
        Differencer.check_request_order(matched_pairs, file_1_pairs, file_2_pairs)
      end)

      Enum.each(expected_output, fn eo ->
        case eo do
          nil -> refute String.contains?(output, "the order of request")
          _any -> assert String.contains?(output, eo)
        end
      end)
    end)
  end

  test "find_nonmatching_matches" do
    test_table = [
      {
        [
          {
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com" },
            },
            %{
              "request" => %{ "method" => "GET", "url" => "www.test2.com" },
            }
          }
        ],
        "Critical - URLs have changed between files: GET www.test.com vs GET www.test2.com"
      },

      {
        [
          {
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com" },
            },
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com" },
            }
          }
        ],
        nil
      },

      {
        [
          {
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com" },
            },
            %{
              "request" => %{ "method" => "POST", "url" => "www.test.com" },
            }
          }
        ],
        "Critical - URLs have changed between files: GET www.test.com vs POST www.test.com"
      },
    ]

    Enum.each(test_table, fn {data, expected_output} ->
      output = capture_io(fn ->
        Differencer.find_nonmatching_matches(data)
      end)

      case expected_output do
        nil -> refute String.contains?(output, "URLs have changed between files")
        _any -> assert String.contains?(output, expected_output)
      end
    end)
  end

  test "check_response_body_keys" do
    test_table = [
      {
        [
          {
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com" },
              "response" => %{ "body" => "{\"key1\": \"test\", \"key2\": \"test\", \"key3\": \"test\"}" },
            },
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com" },
              "response" => %{ "body" => "" },
            }
          }
        ],
        [
          "Info - request GET www.test.com in file 1 returned key key1 in the response body, but in file 2 it didn't",
          "Info - request GET www.test.com in file 1 returned key key2 in the response body, but in file 2 it didn't",
          "Info - request GET www.test.com in file 1 returned key key3 in the response body, but in file 2 it didn't"
        ]
      },

      {
        [
          {

            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com" },
              "response" => %{ "body" => "" },
            },
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com" },
              "response" => %{ "body" => "{\"key1\": \"test\", \"key2\": \"test\", \"key3\": \"test\"}" },
            }
          }
        ],
        [
          "Info - request GET www.test.com in file 2 returned key key1 in the response body, but in file 1 it didn't",
          "Info - request GET www.test.com in file 2 returned key key2 in the response body, but in file 1 it didn't",
          "Info - request GET www.test.com in file 2 returned key key3 in the response body, but in file 1 it didn't"
        ]
      },

      {
        [
          {

            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com" },
              "response" => %{ "body" => "{\"key1\": \"test\", \"key2\": \"test\", \"key3\": \"test\"}" },
            },
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com" },
              "response" => %{ "body" => "{\"key1\": \"test\", \"key2\": \"test\", \"key3\": \"test\"}" },
            }
          }
        ],
        [
          nil
        ]
      },
    ]

    Enum.each(test_table, fn {data, expected_output} ->
      output = capture_io(fn ->
        Differencer.check_response_body_keys(data)
      end)

      Enum.each(expected_output, fn eo ->
        case eo do
          nil -> refute String.contains?(output, "in the response body")
          _any -> assert String.contains?(output, eo)
        end
      end)
    end)
  end

  test "check_request_headers" do
    test_table = [
      {
        [
          {
            %{
              "request" => %{
                "method" => "GET",
                "url" => "www.test.com",
                "headers" => [
                  %{ "name" => "TestHeader1", "value" => "test" },
                  %{ "name" => "TestHeader2", "value" => "test" },
                  %{ "name" => "TestHeader3", "value" => "test" }
                ]
              },
            },
            %{
              "request" => %{
                "method" => "GET",
                "url" => "www.test.com",
                "headers" => [ ]
              },
            }
          }
        ],
        [
          "Warning - file 1 - request GET www.test.com had request header TestHeader1 but file 2 did not",
          "Warning - file 1 - request GET www.test.com had request header TestHeader1 but file 2 did not",
          "Warning - file 1 - request GET www.test.com had request header TestHeader1 but file 2 did not",
        ]
      },

      {
        [
          {
            %{
              "request" => %{
                "method" => "GET",
                "url" => "www.test.com",
                "headers" => [ ]
              },
            },
            %{
              "request" => %{
                "method" => "GET",
                "url" => "www.test.com",
                "headers" => [
                  %{ "name" => "TestHeader1", "value" => "test" },
                  %{ "name" => "TestHeader2", "value" => "test" },
                  %{ "name" => "TestHeader3", "value" => "test" }
                ]
              },
            }
          }
        ],
        [
          "Warning - file 2 - request GET www.test.com had request header TestHeader1 but file 1 did not",
          "Warning - file 2 - request GET www.test.com had request header TestHeader1 but file 1 did not",
          "Warning - file 2 - request GET www.test.com had request header TestHeader1 but file 1 did not",
        ]
      },

      {
        [
          {
            %{
              "request" => %{
                "method" => "GET",
                "url" => "www.test.com",
                "headers" => [
                  %{ "name" => "TestHeader1", "value" => "test" },
                  %{ "name" => "TestHeader2", "value" => "test" },
                  %{ "name" => "TestHeader3", "value" => "test" }
                ]
              },
            },
            %{
              "request" => %{
                "method" => "GET",
                "url" => "www.test.com",
                "headers" => [
                  %{ "name" => "TestHeader1", "value" => "test" },
                  %{ "name" => "TestHeader2", "value" => "test" },
                  %{ "name" => "TestHeader3", "value" => "test" }
                ]
              },
            }
          }
        ],
        [
          nil
        ]
      },

      {
        [
          {
            %{
              "request" => %{
                "method" => "GET",
                "url" => "www.test.com",
                "headers" => [
                  %{ "name" => "TestHeader1", "value" => "test" },
                  %{ "name" => "TestHeader2", "value" => "test" },
                  %{ "name" => "TestHeader3", "value" => "test" }
                ]
              },
            },
            %{
              "request" => %{
                "method" => "GET",
                "url" => "www.test.com",
                "headers" => [
                  %{ "name" => "TestHeader1", "value" => "test" },
                  %{ "name" => "TestHeader3", "value" => "test" },
                  %{ "name" => "TestHeader2", "value" => "test" }
                ]
              },
            }
          }
        ],
        [
          "Notice - request header TestHeader3 moved from position 3 to 2 in request GET www.test.com",
          "Notice - request header TestHeader2 moved from position 2 to 3 in request GET www.test.com",
        ]
      },
    ]

    Enum.each(test_table, fn {data, expected_output} ->
      output = capture_io(fn ->
        Differencer.check_request_headers(data)
      end)

      Enum.each(expected_output, fn eo ->
        case eo do
          nil -> refute String.contains?(output, "in the response body") || String.contains?(output, "moved from position")
          _any -> assert String.contains?(output, eo)
        end
      end)
    end)
  end

  test "find_failed_matches" do
    test_table = [
      {
        [
          {
            %{
              "request" => %{ "method" => "GET", "url" => "www.test2.com", },
            },
            nil
          },
          {
            nil,
            %{
              "request" => %{ "method" => "GET", "url" => "www.test3.com", },
            }
          }
        ],
        [
          "Warning - file 1 made a request to GET www.test2.com but file 2 did not",
          "Warning - file 2 made a request to GET www.test3.com but file 1 did not",
        ]
      },

      {
        [
          {
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com", },
            },
            %{
              "request" => %{ "method" => "GET", "url" => "www.test.com", },
            }
          },
        ],
        [
          nil
        ]
      },
    ]

    Enum.each(test_table, fn {data, expected_output} ->
      output = capture_io(fn ->
        Differencer.find_failed_matches(data)
      end)

      Enum.each(expected_output, fn eo ->
        case eo do
          nil -> refute String.contains?(output, "Warning - file 1 made a request to")
          _any -> assert String.contains?(output, eo)
        end
      end)
    end)
  end
end
