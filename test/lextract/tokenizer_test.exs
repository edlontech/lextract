defmodule LeXtract.TokenizerTest do
  use ExUnit.Case, async: false
  use Mimic

  alias LeXtract.Tokenizer
  alias Tokenizers.Encoding
  alias Tokenizers.Tokenizer, as: HFTokenizer

  setup :verify_on_exit!
  setup :set_mimic_global

  setup do
    Mimic.copy(HFTokenizer)
    Mimic.copy(Encoding)
    Tokenizer.clear_cache()
    :ok
  end

  describe "tokenize/2" do
    test "tokenizes simple English text" do
      text = "Hello world"
      mock_encoding = build_mock_encoding(["hello", "world"], [101, 102], [{0, 5}, {6, 11}])

      expect(HFTokenizer, :from_pretrained, fn "bert-base-uncased" ->
        {:ok, :mock_tokenizer}
      end)

      expect(HFTokenizer, :encode, fn :mock_tokenizer, ^text ->
        {:ok, mock_encoding}
      end)

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert encoding.tokens == ["hello", "world"]
      assert encoding.ids == [101, 102]
      assert encoding.offsets == [{0, 5}, {6, 11}]
    end

    test "handles Unicode text with accents" do
      text = "Café José"
      mock_encoding = build_mock_encoding(["cafe", "jose"], [201, 202], [{0, 4}, {5, 9}])

      expect(HFTokenizer, :from_pretrained, fn _ -> {:ok, :mock_tokenizer} end)
      expect(HFTokenizer, :encode, fn _, ^text -> {:ok, mock_encoding} end)

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert encoding.tokens == ["cafe", "jose"]
      assert length(encoding.tokens) == 2
    end

    test "handles emoji characters" do
      text = "Hello 😁 world"

      mock_encoding =
        build_mock_encoding(["hello", "[UNK]", "world"], [101, 100, 102], [
          {0, 5},
          {6, 10},
          {11, 16}
        ])

      expect(HFTokenizer, :from_pretrained, fn _ -> {:ok, :mock_tokenizer} end)
      expect(HFTokenizer, :encode, fn _, ^text -> {:ok, mock_encoding} end)

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert encoding.tokens == ["hello", "[UNK]", "world"]
      assert encoding.offsets == [{0, 5}, {6, 10}, {11, 16}]
    end

    test "handles text with multiple emojis" do
      text = "Test 🎉 🚀 text"

      mock_encoding =
        build_mock_encoding(
          ["test", "[UNK]", "[UNK]", "text"],
          [101, 100, 100, 102],
          [{0, 4}, {5, 9}, {10, 14}, {15, 19}]
        )

      expect(HFTokenizer, :from_pretrained, fn _ -> {:ok, :mock_tokenizer} end)
      expect(HFTokenizer, :encode, fn _, ^text -> {:ok, mock_encoding} end)

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert length(encoding.tokens) == 4
    end

    test "handles combining characters" do
      text = "naïve café"
      mock_encoding = build_mock_encoding(["naive", "cafe"], [201, 202], [{0, 5}, {6, 10}])

      expect(HFTokenizer, :from_pretrained, fn _ -> {:ok, :mock_tokenizer} end)
      expect(HFTokenizer, :encode, fn _, ^text -> {:ok, mock_encoding} end)

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert encoding.tokens == ["naive", "cafe"]
    end

    test "handles empty string" do
      text = ""
      mock_encoding = build_mock_encoding([], [], [])

      expect(HFTokenizer, :from_pretrained, fn _ -> {:ok, :mock_tokenizer} end)
      expect(HFTokenizer, :encode, fn _, ^text -> {:ok, mock_encoding} end)

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert encoding.tokens == []
      assert encoding.ids == []
      assert encoding.offsets == []
    end

    test "handles very long text" do
      text = String.duplicate("word ", 1000)
      tokens = List.duplicate("word", 1000)
      ids = Enum.map(1..1000, fn _ -> 42 end)
      offsets = Enum.map(0..999, fn i -> {i * 5, i * 5 + 4} end)

      mock_encoding = build_mock_encoding(tokens, ids, offsets)

      expect(HFTokenizer, :from_pretrained, fn _ -> {:ok, :mock_tokenizer} end)
      expect(HFTokenizer, :encode, fn _, ^text -> {:ok, mock_encoding} end)

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert length(encoding.tokens) == 1000
      assert length(encoding.offsets) == 1000
    end

    test "uses custom tokenizer when provided" do
      text = "Test"
      custom_tokenizer = :custom_tokenizer
      mock_encoding = build_mock_encoding(["test"], [42], [{0, 4}])

      expect(HFTokenizer, :encode, fn ^custom_tokenizer, ^text ->
        {:ok, mock_encoding}
      end)

      {:ok, encoding} = Tokenizer.tokenize(text, tokenizer: custom_tokenizer)

      assert encoding.tokens == ["test"]
    end

    test "returns error when tokenizer fails to load" do
      expect(HFTokenizer, :from_pretrained, fn _ ->
        {:error, :network_error}
      end)

      {:error, :network_error} = Tokenizer.tokenize("test")
    end

    test "returns error when encoding fails" do
      expect(HFTokenizer, :from_pretrained, fn _ -> {:ok, :mock_tokenizer} end)
      expect(HFTokenizer, :encode, fn _, _ -> {:error, :encoding_failed} end)

      {:error, :encoding_failed} = Tokenizer.tokenize("test")
    end
  end

  describe "get_token/2" do
    test "gets token at valid index" do
      encoding = %{
        tokens: ["hello", "world"],
        ids: [1, 2],
        offsets: [{0, 5}, {6, 11}],
        encoding: :mock
      }

      assert Tokenizer.get_token(encoding, 0) == "hello"
      assert Tokenizer.get_token(encoding, 1) == "world"
    end

    test "returns nil for out of bounds index" do
      encoding = %{
        tokens: ["hello"],
        ids: [1],
        offsets: [{0, 5}],
        encoding: :mock
      }

      assert Tokenizer.get_token(encoding, 999) == nil
      assert Tokenizer.get_token(encoding, -1) == nil
    end

    test "handles empty token list" do
      encoding = %{
        tokens: [],
        ids: [],
        offsets: [],
        encoding: :mock
      }

      assert Tokenizer.get_token(encoding, 0) == nil
    end
  end

  describe "get_tokens/1" do
    test "returns all tokens" do
      encoding = %{
        tokens: ["hello", "world", "test"],
        ids: [1, 2, 3],
        offsets: [{0, 5}, {6, 11}, {12, 16}],
        encoding: :mock
      }

      assert Tokenizer.get_tokens(encoding) == ["hello", "world", "test"]
    end

    test "returns empty list for empty encoding" do
      encoding = %{
        tokens: [],
        ids: [],
        offsets: [],
        encoding: :mock
      }

      assert Tokenizer.get_tokens(encoding) == []
    end
  end

  describe "get_offset/2" do
    test "gets offset at valid index" do
      encoding = %{
        tokens: ["hello", "world"],
        ids: [1, 2],
        offsets: [{0, 5}, {6, 11}],
        encoding: :mock
      }

      assert Tokenizer.get_offset(encoding, 0) == {0, 5}
      assert Tokenizer.get_offset(encoding, 1) == {6, 11}
    end

    test "returns nil for out of bounds index" do
      encoding = %{
        tokens: ["hello"],
        ids: [1],
        offsets: [{0, 5}],
        encoding: :mock
      }

      assert Tokenizer.get_offset(encoding, 999) == nil
    end

    test "handles emoji offsets correctly" do
      encoding = %{
        tokens: ["hello", "[UNK]"],
        ids: [1, 100],
        offsets: [{0, 5}, {6, 10}],
        encoding: :mock
      }

      {start_pos, end_pos} = Tokenizer.get_offset(encoding, 1)
      assert start_pos == 6
      assert end_pos == 10
    end
  end

  describe "get_offsets/1" do
    test "returns all offsets" do
      encoding = %{
        tokens: ["a", "b", "c"],
        ids: [1, 2, 3],
        offsets: [{0, 1}, {2, 3}, {4, 5}],
        encoding: :mock
      }

      assert Tokenizer.get_offsets(encoding) == [{0, 1}, {2, 3}, {4, 5}]
    end

    test "returns empty list for empty encoding" do
      encoding = %{
        tokens: [],
        ids: [],
        offsets: [],
        encoding: :mock
      }

      assert Tokenizer.get_offsets(encoding) == []
    end
  end

  describe "find_sequence/3" do
    test "finds token sequence at beginning" do
      encoding = %{
        tokens: ["hello", "world", "test"],
        ids: [1, 2, 3],
        offsets: [{0, 5}, {6, 11}, {12, 16}],
        encoding: :mock
      }

      assert Tokenizer.find_sequence(encoding, ["hello", "world"]) == {:ok, 0, 2}
    end

    test "finds token sequence in middle" do
      encoding = %{
        tokens: ["the", "quick", "brown", "fox"],
        ids: [1, 2, 3, 4],
        offsets: [{0, 3}, {4, 9}, {10, 15}, {16, 19}],
        encoding: :mock
      }

      assert Tokenizer.find_sequence(encoding, ["quick", "brown"]) == {:ok, 1, 3}
    end

    test "finds token sequence at end" do
      encoding = %{
        tokens: ["hello", "world", "test"],
        ids: [1, 2, 3],
        offsets: [{0, 5}, {6, 11}, {12, 16}],
        encoding: :mock
      }

      assert Tokenizer.find_sequence(encoding, ["world", "test"]) == {:ok, 1, 3}
    end

    test "finds single token" do
      encoding = %{
        tokens: ["hello", "world"],
        ids: [1, 2],
        offsets: [{0, 5}, {6, 11}],
        encoding: :mock
      }

      assert Tokenizer.find_sequence(encoding, ["world"]) == {:ok, 1, 2}
    end

    test "returns not_found for missing sequence" do
      encoding = %{
        tokens: ["hello", "world"],
        ids: [1, 2],
        offsets: [{0, 5}, {6, 11}],
        encoding: :mock
      }

      assert Tokenizer.find_sequence(encoding, ["missing", "tokens"]) == :not_found
    end

    test "case insensitive search by default" do
      encoding = %{
        tokens: ["Hello", "World"],
        ids: [1, 2],
        offsets: [{0, 5}, {6, 11}],
        encoding: :mock
      }

      assert Tokenizer.find_sequence(encoding, ["hello", "world"]) == {:ok, 0, 2}
      assert Tokenizer.find_sequence(encoding, ["HELLO", "WORLD"]) == {:ok, 0, 2}
    end

    test "case sensitive search when specified" do
      encoding = %{
        tokens: ["Hello", "World"],
        ids: [1, 2],
        offsets: [{0, 5}, {6, 11}],
        encoding: :mock
      }

      assert Tokenizer.find_sequence(encoding, ["Hello", "World"], case_sensitive: true) ==
               {:ok, 0, 2}

      assert Tokenizer.find_sequence(encoding, ["hello", "world"], case_sensitive: true) ==
               :not_found
    end

    test "handles empty needle list" do
      encoding = %{
        tokens: ["hello"],
        ids: [1],
        offsets: [{0, 5}],
        encoding: :mock
      }

      assert Tokenizer.find_sequence(encoding, []) == {:ok, 0, 0}
    end

    test "handles partial matches" do
      encoding = %{
        tokens: ["hello", "world", "hello", "test"],
        ids: [1, 2, 1, 3],
        offsets: [{0, 5}, {6, 11}, {12, 17}, {18, 22}],
        encoding: :mock
      }

      assert Tokenizer.find_sequence(encoding, ["hello", "test"]) == {:ok, 2, 4}
    end

    test "returns first match when multiple exist" do
      encoding = %{
        tokens: ["a", "b", "a", "b"],
        ids: [1, 2, 1, 2],
        offsets: [{0, 1}, {2, 3}, {4, 5}, {6, 7}],
        encoding: :mock
      }

      assert Tokenizer.find_sequence(encoding, ["a", "b"]) == {:ok, 0, 2}
    end
  end

  describe "default_tokenizer/0" do
    test "loads and caches default tokenizer" do
      expect(HFTokenizer, :from_pretrained, fn "bert-base-uncased" ->
        {:ok, :cached_tokenizer}
      end)

      {:ok, tokenizer1} = Tokenizer.default_tokenizer()
      assert tokenizer1 == :cached_tokenizer

      {:ok, tokenizer2} = Tokenizer.default_tokenizer()
      assert tokenizer2 == :cached_tokenizer
    end

    test "returns error when loading fails" do
      expect(HFTokenizer, :from_pretrained, fn _ ->
        {:error, :load_failed}
      end)

      assert {:error, :load_failed} = Tokenizer.default_tokenizer()
    end
  end

  describe "clear_cache/0" do
    test "clears cached tokenizer" do
      expect(HFTokenizer, :from_pretrained, 2, fn "bert-base-uncased" ->
        {:ok, :mock_tokenizer}
      end)

      {:ok, _} = Tokenizer.default_tokenizer()
      :ok = Tokenizer.clear_cache()
      {:ok, _} = Tokenizer.default_tokenizer()
    end
  end

  describe "edge cases" do
    test "handles text with only whitespace" do
      text = "   "
      mock_encoding = build_mock_encoding([], [], [])

      expect(HFTokenizer, :from_pretrained, fn _ -> {:ok, :mock_tokenizer} end)
      expect(HFTokenizer, :encode, fn _, ^text -> {:ok, mock_encoding} end)

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert encoding.tokens == []
    end

    test "handles text with special characters" do
      text = "@#$%^&*()"
      mock_encoding = build_mock_encoding(["@", "#", "$"], [1, 2, 3], [{0, 1}, {1, 2}, {2, 3}])

      expect(HFTokenizer, :from_pretrained, fn _ -> {:ok, :mock_tokenizer} end)
      expect(HFTokenizer, :encode, fn _, ^text -> {:ok, mock_encoding} end)

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert length(encoding.tokens) == 3
    end

    test "handles text with newlines" do
      text = "line1\nline2\nline3"

      mock_encoding =
        build_mock_encoding(["line1", "line2", "line3"], [1, 2, 3], [{0, 5}, {6, 11}, {12, 17}])

      expect(HFTokenizer, :from_pretrained, fn _ -> {:ok, :mock_tokenizer} end)
      expect(HFTokenizer, :encode, fn _, ^text -> {:ok, mock_encoding} end)

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert encoding.tokens == ["line1", "line2", "line3"]
    end

    test "handles text with tabs" do
      text = "word1\tword2"
      mock_encoding = build_mock_encoding(["word1", "word2"], [1, 2], [{0, 5}, {6, 11}])

      expect(HFTokenizer, :from_pretrained, fn _ -> {:ok, :mock_tokenizer} end)
      expect(HFTokenizer, :encode, fn _, ^text -> {:ok, mock_encoding} end)

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert encoding.tokens == ["word1", "word2"]
    end

    test "handles Chinese characters" do
      text = "你好世界"

      mock_encoding =
        build_mock_encoding(["你", "好", "世", "界"], [1, 2, 3, 4], [{0, 3}, {3, 6}, {6, 9}, {9, 12}])

      expect(HFTokenizer, :from_pretrained, fn _ -> {:ok, :mock_tokenizer} end)
      expect(HFTokenizer, :encode, fn _, ^text -> {:ok, mock_encoding} end)

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert length(encoding.tokens) == 4
    end

    test "handles Arabic characters" do
      text = "مرحبا"
      mock_encoding = build_mock_encoding(["مرحبا"], [1], [{0, 10}])

      expect(HFTokenizer, :from_pretrained, fn _ -> {:ok, :mock_tokenizer} end)
      expect(HFTokenizer, :encode, fn _, ^text -> {:ok, mock_encoding} end)

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert encoding.tokens == ["مرحبا"]
    end

    test "handles mixed scripts" do
      text = "Hello नमस्ते 你好"

      mock_encoding =
        build_mock_encoding(["hello", "नमस्ते", "你好"], [1, 2, 3], [{0, 5}, {6, 18}, {19, 25}])

      expect(HFTokenizer, :from_pretrained, fn _ -> {:ok, :mock_tokenizer} end)
      expect(HFTokenizer, :encode, fn _, ^text -> {:ok, mock_encoding} end)

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert length(encoding.tokens) == 3
    end
  end

  describe "performance" do
    test "tokenizes typical text in reasonable time" do
      text = "The patient was prescribed aspirin 81mg daily for cardiovascular health."

      mock_encoding =
        build_mock_encoding(
          String.split(String.downcase(text)),
          Enum.to_list(1..12),
          Enum.with_index(String.split(text), fn _, i -> {i * 6, i * 6 + 5} end)
        )

      expect(HFTokenizer, :from_pretrained, fn _ -> {:ok, :mock_tokenizer} end)
      expect(HFTokenizer, :encode, fn _, ^text -> {:ok, mock_encoding} end)

      {time_us, {:ok, _encoding}} = :timer.tc(fn -> Tokenizer.tokenize(text) end)

      assert time_us < 1_000_000
    end
  end

  defp build_mock_encoding(tokens, ids, offsets) do
    encoding_stub = %{
      __struct__: Encoding,
      tokens: tokens,
      ids: ids,
      offsets: offsets
    }

    stub(Encoding, :get_tokens, fn ^encoding_stub -> tokens end)
    stub(Encoding, :get_ids, fn ^encoding_stub -> ids end)
    stub(Encoding, :get_offsets, fn ^encoding_stub -> offsets end)

    encoding_stub
  end
end
