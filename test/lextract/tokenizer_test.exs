defmodule LeXtract.TokenizerTest do
  use ExUnit.Case, async: false

  alias LeXtract.Tokenizer
  alias Tokenizers.Encoding
  alias Tokenizers.Tokenizer, as: HFTokenizer

  setup do
    Tokenizer.clear_cache()
    :ok
  end

  describe "tokenize/2" do
    test "tokenizes simple English text" do
      text = "Hello world"

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert is_list(encoding.tokens)
      assert is_list(encoding.ids)
      assert is_list(encoding.offsets)
      assert length(encoding.tokens) > 0
      assert encoding.text == text
    end

    test "handles Unicode text with accents" do
      text = "Café José"

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert is_list(encoding.tokens)
      assert length(encoding.tokens) > 0
    end

    test "handles emoji characters" do
      text = "Hello 😁 world"

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert is_list(encoding.tokens)
      assert length(encoding.tokens) > 0
      assert is_list(encoding.offsets)
    end

    test "handles text with multiple emojis" do
      text = "Test 🎉 🚀 text"

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert length(encoding.tokens) > 0
    end

    test "handles combining characters" do
      text = "naïve café"

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert is_list(encoding.tokens)
      assert length(encoding.tokens) > 0
    end

    test "handles empty string" do
      text = ""

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert is_list(encoding.tokens)
      assert is_list(encoding.ids)
      assert is_list(encoding.offsets)
    end

    test "handles very long text" do
      text = String.duplicate("word ", 1000)

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert length(encoding.tokens) > 0
      assert length(encoding.offsets) > 0
    end

    test "uses custom tokenizer when provided" do
      Mimic.copy(HFTokenizer)

      text = "Test"
      custom_tokenizer = :custom_tokenizer
      mock_encoding = build_mock_encoding(["test"], [42], [{0, 4}])

      Mimic.expect(HFTokenizer, :encode, fn ^custom_tokenizer, ^text ->
        {:ok, mock_encoding}
      end)

      {:ok, encoding} = Tokenizer.tokenize(text, tokenizer: custom_tokenizer)

      assert encoding.tokens == ["test"]
    end

    test "returns error when encoding fails" do
      Mimic.copy(HFTokenizer)

      {:ok, tokenizer} = Tokenizer.default_tokenizer()

      Mimic.stub(HFTokenizer, :encode, fn ^tokenizer, _ ->
        {:error, :encoding_failed}
      end)

      {:error, %LeXtract.Error.Processing.Tokenization{}} = Tokenizer.tokenize("test")
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
      {:ok, tokenizer1} = Tokenizer.default_tokenizer()
      assert is_struct(tokenizer1)

      {:ok, tokenizer2} = Tokenizer.default_tokenizer()
      assert tokenizer1 == tokenizer2
    end
  end

  describe "clear_cache/0" do
    test "clears cached tokenizer" do
      {:ok, tokenizer1} = Tokenizer.default_tokenizer()
      :ok = Tokenizer.clear_cache()
      {:ok, tokenizer2} = Tokenizer.default_tokenizer()

      assert is_struct(tokenizer1)
      assert is_struct(tokenizer2)
    end
  end

  describe "edge cases" do
    test "handles text with only whitespace" do
      text = "   "

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert is_list(encoding.tokens)
    end

    test "handles text with special characters" do
      text = "@#$%^&*()"

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert length(encoding.tokens) >= 0
    end

    test "handles text with newlines" do
      text = "line1\nline2\nline3"

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert is_list(encoding.tokens)
      assert length(encoding.tokens) > 0
    end

    test "handles text with tabs" do
      text = "word1\tword2"

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert is_list(encoding.tokens)
      assert length(encoding.tokens) > 0
    end

    test "handles Chinese characters" do
      text = "你好世界"

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert length(encoding.tokens) > 0
    end

    test "handles Arabic characters" do
      text = "مرحبا"

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert is_list(encoding.tokens)
      assert length(encoding.tokens) > 0
    end

    test "handles mixed scripts" do
      text = "Hello नमस्ते 你好"

      {:ok, encoding} = Tokenizer.tokenize(text)

      assert length(encoding.tokens) > 0
    end
  end

  defp build_mock_encoding(tokens, ids, offsets) do
    Mimic.copy(Encoding)

    encoding_stub = %{
      __struct__: Encoding,
      tokens: tokens,
      ids: ids,
      offsets: offsets
    }

    Mimic.stub(Encoding, :get_tokens, fn ^encoding_stub -> tokens end)
    Mimic.stub(Encoding, :get_ids, fn ^encoding_stub -> ids end)
    Mimic.stub(Encoding, :get_offsets, fn ^encoding_stub -> offsets end)

    encoding_stub
  end
end
