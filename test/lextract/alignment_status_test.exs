defmodule LeXtract.AlignmentStatusTest do
  use ExUnit.Case, async: true
  doctest LeXtract.AlignmentStatus

  alias LeXtract.AlignmentStatus

  describe "exact?/1" do
    test "returns true for :exact" do
      assert AlignmentStatus.exact?(:exact)
    end

    test "returns false for :fuzzy" do
      refute AlignmentStatus.exact?(:fuzzy)
    end

    test "returns false for :partial" do
      refute AlignmentStatus.exact?(:partial)
    end

    test "returns false for :none" do
      refute AlignmentStatus.exact?(:none)
    end
  end

  describe "matched?/1" do
    test "returns true for :exact" do
      assert AlignmentStatus.matched?(:exact)
    end

    test "returns true for :fuzzy" do
      assert AlignmentStatus.matched?(:fuzzy)
    end

    test "returns true for :partial" do
      assert AlignmentStatus.matched?(:partial)
    end

    test "returns false for :none" do
      refute AlignmentStatus.matched?(:none)
    end
  end

  describe "confidence/1" do
    test "returns 1.0 for :exact" do
      assert AlignmentStatus.confidence(:exact) == 1.0
    end

    test "returns 0.8 for :fuzzy" do
      assert AlignmentStatus.confidence(:fuzzy) == 0.8
    end

    test "returns 0.5 for :partial" do
      assert AlignmentStatus.confidence(:partial) == 0.5
    end

    test "returns 0.0 for :none" do
      assert AlignmentStatus.confidence(:none) == 0.0
    end
  end

  describe "from_string/1" do
    test "converts 'exact' to :exact" do
      assert AlignmentStatus.from_string("exact") == :exact
    end

    test "converts 'fuzzy' to :fuzzy" do
      assert AlignmentStatus.from_string("fuzzy") == :fuzzy
    end

    test "converts 'partial' to :partial" do
      assert AlignmentStatus.from_string("partial") == :partial
    end

    test "converts 'none' to :none" do
      assert AlignmentStatus.from_string("none") == :none
    end

    test "returns :none for unknown strings" do
      assert AlignmentStatus.from_string("unknown") == :none
      assert AlignmentStatus.from_string("") == :none
      assert AlignmentStatus.from_string("invalid") == :none
    end
  end
end
