defmodule LeXtract.CharIntervalTest do
  use ExUnit.Case, async: true
  doctest LeXtract.CharInterval

  alias LeXtract.CharInterval

  describe "new/2" do
    test "creates interval with valid positions" do
      interval = CharInterval.new(0, 10)

      assert interval.start_pos == 0
      assert interval.end_pos == 10
    end

    test "creates interval with equal start and end" do
      interval = CharInterval.new(5, 5)

      assert interval.start_pos == 5
      assert interval.end_pos == 5
    end

    test "raises FunctionClauseError when start > end" do
      assert_raise FunctionClauseError, fn ->
        CharInterval.new(10, 5)
      end
    end
  end

  describe "length/1" do
    test "returns length of interval" do
      interval = CharInterval.new(10, 20)

      assert CharInterval.length(interval) == 10
    end

    test "returns 0 for empty interval" do
      interval = CharInterval.new(5, 5)

      assert CharInterval.length(interval) == 0
    end

    test "returns correct length for large interval" do
      interval = CharInterval.new(0, 1000)

      assert CharInterval.length(interval) == 1000
    end
  end

  describe "extract/2" do
    test "extracts substring from text" do
      interval = CharInterval.new(0, 5)
      text = "Hello, world!"

      assert CharInterval.extract(text, interval) == "Hello"
    end

    test "extracts middle section" do
      interval = CharInterval.new(7, 12)
      text = "Hello, world!"

      assert CharInterval.extract(text, interval) == "world"
    end

    test "extracts empty string for zero-length interval" do
      interval = CharInterval.new(5, 5)
      text = "Hello, world!"

      assert CharInterval.extract(text, interval) == ""
    end

    test "handles UTF-8 characters correctly" do
      interval = CharInterval.new(0, 3)
      text = "café"

      assert CharInterval.extract(text, interval) == "caf"
    end
  end

  describe "overlaps?/2" do
    test "returns true for overlapping intervals" do
      i1 = CharInterval.new(0, 5)
      i2 = CharInterval.new(3, 8)

      assert CharInterval.overlaps?(i1, i2)
      assert CharInterval.overlaps?(i2, i1)
    end

    test "returns false for adjacent intervals" do
      i1 = CharInterval.new(0, 5)
      i2 = CharInterval.new(5, 10)

      refute CharInterval.overlaps?(i1, i2)
      refute CharInterval.overlaps?(i2, i1)
    end

    test "returns false for separate intervals" do
      i1 = CharInterval.new(0, 5)
      i2 = CharInterval.new(10, 15)

      refute CharInterval.overlaps?(i1, i2)
      refute CharInterval.overlaps?(i2, i1)
    end

    test "returns true for contained interval" do
      i1 = CharInterval.new(0, 10)
      i2 = CharInterval.new(3, 7)

      assert CharInterval.overlaps?(i1, i2)
      assert CharInterval.overlaps?(i2, i1)
    end

    test "returns true for identical intervals" do
      i1 = CharInterval.new(5, 10)
      i2 = CharInterval.new(5, 10)

      assert CharInterval.overlaps?(i1, i2)
    end

    test "returns false for zero-length intervals that touch" do
      i1 = CharInterval.new(0, 5)
      i2 = CharInterval.new(5, 5)

      refute CharInterval.overlaps?(i1, i2)
      refute CharInterval.overlaps?(i2, i1)
    end
  end
end
