defmodule HTTPComparerTest do
  use ExUnit.Case
  doctest HTTPComparer.Application

  import ExUnit.CaptureIO

  test "everything" do
    output = capture_io(fn ->
      HTTPComparer.Application.application("./test/test_files/13.3.7.json", "./test/test_files/13.4.0.json", true)
    end)

    # Just a simple test to make sure there is nothing obvious broken.
    assert String.contains?(output, "Warning - file 1 made a request to GET https://thebank.teller.engineering/api/apps/A3254414/configuration but file 2 did not")
  end

  test "duplicate checking works" do
    test_table = [{"./test/test_files/test1.json", "./test/test_files/test1.json", "Critical - request GET https://status.thebank.teller.engineering/status.json appears more than once in the same file; results will be inaccurate"},
      {"./test/test_files/test2.json", "./test/test_files/test2.json", ""}]

    Enum.each(test_table, fn {file_1_path, file_2_path, expected_output} ->
      output = capture_io(fn ->
        HTTPComparer.Application.application(file_1_path, file_2_path, true)
      end)

      case expected_output do
        nil -> refute String.contains?(output, "appears more than once")
        _any -> assert String.contains?(output, expected_output)
      end
    end)
  end
end
