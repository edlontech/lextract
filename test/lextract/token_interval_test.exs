defmodule LeXtract.TokenIntervalTest do
  use ExUnit.Case, async: true
  doctest LeXtract.TokenInterval

  alias LeXtract.TokenInterval

  describe "new/2" do
    test "creates interval with valid tokens" do
      interval = TokenInterval.new(0, 5)

      assert interval.start_token == 0
      assert interval.end_token == 5
    end

    test "creates interval with equal start and end" do
      interval = TokenInterval.new(3, 3)

      assert interval.start_token == 3
      assert interval.end_token == 3
    end

    test "raises FunctionClauseError when start > end" do
      assert_raise FunctionClauseError, fn ->
        TokenInterval.new(10, 5)
      end
    end
  end

  describe "length/1" do
    test "returns number of tokens" do
      interval = TokenInterval.new(5, 10)

      assert TokenInterval.length(interval) == 5
    end

    test "returns 0 for empty interval" do
      interval = TokenInterval.new(3, 3)

      assert TokenInterval.length(interval) == 0
    end

    test "returns correct length for large interval" do
      interval = TokenInterval.new(0, 100)

      assert TokenInterval.length(interval) == 100
    end
  end

  describe "overlaps?/2" do
    test "returns true for overlapping intervals" do
      i1 = TokenInterval.new(0, 5)
      i2 = TokenInterval.new(3, 8)

      assert TokenInterval.overlaps?(i1, i2)
      assert TokenInterval.overlaps?(i2, i1)
    end

    test "returns false for adjacent intervals" do
      i1 = TokenInterval.new(0, 5)
      i2 = TokenInterval.new(5, 10)

      refute TokenInterval.overlaps?(i1, i2)
      refute TokenInterval.overlaps?(i2, i1)
    end

    test "returns false for separate intervals" do
      i1 = TokenInterval.new(0, 5)
      i2 = TokenInterval.new(10, 15)

      refute TokenInterval.overlaps?(i1, i2)
      refute TokenInterval.overlaps?(i2, i1)
    end

    test "returns true for contained interval" do
      i1 = TokenInterval.new(0, 10)
      i2 = TokenInterval.new(3, 7)

      assert TokenInterval.overlaps?(i1, i2)
      assert TokenInterval.overlaps?(i2, i1)
    end

    test "returns true for identical intervals" do
      i1 = TokenInterval.new(5, 10)
      i2 = TokenInterval.new(5, 10)

      assert TokenInterval.overlaps?(i1, i2)
    end

    test "returns false for zero-length intervals that touch" do
      i1 = TokenInterval.new(0, 5)
      i2 = TokenInterval.new(5, 5)

      refute TokenInterval.overlaps?(i1, i2)
      refute TokenInterval.overlaps?(i2, i1)
    end
  end
end
