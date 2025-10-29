defmodule LeXtract.AlignmentTest do
  use ExUnit.Case, async: false

  alias LeXtract.{Alignment, CharInterval, Extraction, Tokenizer}

  describe "align_extraction/2 - exact matches" do
    test "aligns simple exact match" do
      source_text = "The patient John Doe was prescribed medication"
      extraction_text = "John Doe"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "person",
        extraction_text: extraction_text,
        extraction_index: 0
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :exact
      assert aligned.char_interval == %CharInterval{start_pos: 12, end_pos: 20}
      assert aligned.extraction_text == "John Doe"
    end

    test "aligns single word extraction" do
      source_text = "Patient takes aspirin daily"
      extraction_text = "aspirin"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "medication",
        extraction_text: extraction_text,
        extraction_index: 0
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :exact
      assert aligned.char_interval == %CharInterval{start_pos: 14, end_pos: 21}
    end

    test "aligns extraction at beginning of text" do
      source_text = "Aspirin 81mg was prescribed"
      extraction_text = "Aspirin"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "medication",
        extraction_text: extraction_text,
        extraction_index: 0
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :exact
      assert aligned.char_interval == %CharInterval{start_pos: 0, end_pos: 7}
    end

    test "aligns extraction at end of text" do
      source_text = "The medication is ibuprofen"
      extraction_text = "ibuprofen"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "medication",
        extraction_text: extraction_text,
        extraction_index: 0
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :exact
      assert aligned.char_interval == %CharInterval{start_pos: 18, end_pos: 27}
    end
  end

  describe "align_extraction/2 - case insensitive matches" do
    test "aligns with different case - uppercase extraction" do
      source_text = "Patient: john doe"
      extraction_text = "JOHN DOE"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "person",
        extraction_text: extraction_text,
        extraction_index: 0
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :exact
      assert aligned.char_interval == %CharInterval{start_pos: 9, end_pos: 17}
    end

    test "aligns with different case - mixed case" do
      source_text = "The PATIENT takes Aspirin"
      extraction_text = "the patient"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "phrase",
        extraction_text: extraction_text,
        extraction_index: 0
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :exact
      assert aligned.char_interval == %CharInterval{start_pos: 0, end_pos: 11}
    end
  end

  describe "align_extraction/2 - fuzzy matches" do
    test "aligns with minor spelling variation" do
      source_text = "Patient takes ibuprofin daily"
      extraction_text = "ibuprofen"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "medication",
        extraction_text: extraction_text,
        extraction_index: 0
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :fuzzy
      assert aligned.char_interval == %CharInterval{start_pos: 14, end_pos: 23}
    end

    test "aligns LLM paraphrased text" do
      source_text = "Dr Smith prescribed medication for pain"
      extraction_text = "Doctor Smith"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "person",
        extraction_text: extraction_text,
        extraction_index: 0
      }

      aligned = Alignment.align_extraction(extraction, source_encoding, fuzzy_threshold: 0.75)

      assert aligned.alignment_status == :fuzzy
      assert aligned.char_interval == %CharInterval{start_pos: 0, end_pos: 8}
    end
  end

  describe "align_extraction/2 - partial matches" do
    test "aligns with partial overlap" do
      source_text = "Patient John M Doe was seen"
      extraction_text = "John Doe"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "person",
        extraction_text: extraction_text,
        extraction_index: 0
      }

      aligned =
        Alignment.align_extraction(extraction, source_encoding,
          fuzzy_threshold: 0.7,
          min_partial_length: 1
        )

      assert aligned.alignment_status in [:partial, :exact, :fuzzy]
      assert aligned.char_interval != nil
    end
  end

  describe "align_extraction/2 - multiple occurrences" do
    test "aligns first occurrence with extraction_index 0" do
      source_text = "John likes John very much"
      extraction_text = "John"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "person",
        extraction_text: extraction_text,
        extraction_index: 0
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :exact
      assert aligned.char_interval == %CharInterval{start_pos: 0, end_pos: 4}
    end

    test "aligns second occurrence with extraction_index 1" do
      source_text = "John likes John very much"
      extraction_text = "John"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "person",
        extraction_text: extraction_text,
        extraction_index: 1
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :exact
      assert aligned.char_interval == %CharInterval{start_pos: 11, end_pos: 15}
    end

    test "aligns third occurrence of phrase" do
      source_text = "Take aspirin. Patient takes aspirin. Prescribed aspirin 81mg"
      extraction_text = "aspirin"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "medication",
        extraction_text: extraction_text,
        extraction_index: 2
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :exact
      assert aligned.char_interval == %CharInterval{start_pos: 48, end_pos: 55}
    end
  end

  describe "align_extraction/2 - unicode and special characters" do
    test "aligns text with accented characters" do
      source_text = "Patient José García visited"
      extraction_text = "José García"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "person",
        extraction_text: extraction_text,
        extraction_index: 0
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :exact
      assert aligned.char_interval == %CharInterval{start_pos: 8, end_pos: 19}
    end

    test "aligns text with emoji" do
      source_text = "Patient feels great 😊 today"
      extraction_text = "feels great"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "phrase",
        extraction_text: extraction_text,
        extraction_index: 0
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :exact
      assert aligned.char_interval == %CharInterval{start_pos: 8, end_pos: 19}
    end

    test "aligns text with Chinese characters" do
      source_text = "Patient name: 张伟 is here"
      extraction_text = "张伟"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "person",
        extraction_text: extraction_text,
        extraction_index: 0
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :exact
      assert aligned.char_interval == %CharInterval{start_pos: 14, end_pos: 16}
      assert CharInterval.extract(source_text, aligned.char_interval) == "张伟"
    end
  end

  describe "align_extraction/2 - edge cases" do
    test "handles extraction with punctuation" do
      source_text = "Dr. Smith prescribed medication"
      extraction_text = "Dr. Smith"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "person",
        extraction_text: extraction_text,
        extraction_index: 0
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :exact
      assert aligned.char_interval == %CharInterval{start_pos: 0, end_pos: 9}
    end

    test "handles extraction with extra whitespace" do
      source_text = "Patient takes  aspirin  daily"
      extraction_text = "aspirin"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "medication",
        extraction_text: extraction_text,
        extraction_index: 0
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :exact
      assert aligned.char_interval == %CharInterval{start_pos: 15, end_pos: 22}
    end

    test "handles very long extraction" do
      source_text =
        "Patient John Smith Doe Junior was prescribed aspirin 81mg daily for pain management"

      extraction_text = "John Smith Doe Junior"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "person",
        extraction_text: extraction_text,
        extraction_index: 0
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :exact
      assert aligned.char_interval == %CharInterval{start_pos: 8, end_pos: 29}
    end

    test "returns :none status when no match found" do
      source_text = "Patient takes aspirin daily"
      extraction_text = "ibuprofen"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "medication",
        extraction_text: extraction_text,
        extraction_index: 0
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :none
      assert aligned.char_interval == nil
    end

    test "handles empty extraction text" do
      source_text = "Patient takes aspirin"
      extraction_text = ""

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "medication",
        extraction_text: extraction_text,
        extraction_index: 0
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :none
      assert aligned.char_interval == nil
    end

    test "handles extraction_index beyond available occurrences" do
      source_text = "Patient John was seen"
      extraction_text = "John"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "person",
        extraction_text: extraction_text,
        extraction_index: 5
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :none
      assert aligned.char_interval == nil
    end
  end

  describe "find_match/3" do
    test "finds exact match with occurrence index 0" do
      source_text = "The patient John Doe was seen"
      extraction_text = "John Doe"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      result = Alignment.find_match(extraction_text, source_encoding, 0)

      assert result.alignment_status == :exact
      assert result.char_interval == %CharInterval{start_pos: 12, end_pos: 20}
    end

    test "finds case insensitive match" do
      source_text = "patient john doe"
      extraction_text = "JOHN DOE"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      result = Alignment.find_match(extraction_text, source_encoding, 0)

      assert result.alignment_status == :exact
      assert result.char_interval == %CharInterval{start_pos: 8, end_pos: 16}
    end

    test "returns nil when no match found" do
      source_text = "Patient takes aspirin"
      extraction_text = "missing text"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      result = Alignment.find_match(extraction_text, source_encoding, 0)

      assert result == nil
    end
  end

  describe "search_tokens/4" do
    test "finds token sequence at start" do
      source_text = "hello world test"
      needle = ["hello", "world"]

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)
      haystack = Tokenizer.get_tokens(source_encoding)

      result = Alignment.search_tokens(needle, haystack, source_encoding, 0)

      assert result == %CharInterval{start_pos: 0, end_pos: 11}
    end

    test "finds token sequence in middle" do
      source_text = "the quick brown fox"
      needle = ["quick", "brown"]

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)
      haystack = Tokenizer.get_tokens(source_encoding)

      result = Alignment.search_tokens(needle, haystack, source_encoding, 0)

      assert result == %CharInterval{start_pos: 4, end_pos: 15}
    end

    test "returns nil for empty needle" do
      source_text = "hello world"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)
      haystack = Tokenizer.get_tokens(source_encoding)

      result = Alignment.search_tokens([], haystack, source_encoding, 0)

      assert result == nil
    end

    test "finds second occurrence with index 1" do
      source_text = "test word test again"
      needle = ["test"]

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)
      haystack = Tokenizer.get_tokens(source_encoding)

      result = Alignment.search_tokens(needle, haystack, source_encoding, 1)

      assert result == %CharInterval{start_pos: 10, end_pos: 14}
    end

    test "respects case_sensitive option" do
      source_text = "Hello World"
      needle = ["hello", "world"]

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)
      haystack = Tokenizer.get_tokens(source_encoding)

      result_insensitive =
        Alignment.search_tokens(needle, haystack, source_encoding, 0, case_sensitive: false)

      assert result_insensitive == %CharInterval{start_pos: 0, end_pos: 11}

      result_sensitive =
        Alignment.search_tokens(needle, haystack, source_encoding, 0, case_sensitive: true)

      assert result_sensitive == nil
    end
  end

  describe "integration with real tokenizer" do
    test "end-to-end alignment with real tokenizer" do
      source_text = "Patient John Smith was prescribed aspirin 81mg daily"
      extraction_text = "aspirin 81mg"

      {:ok, source_encoding} = Tokenizer.tokenize(source_text)

      extraction = %Extraction{
        extraction_class: "medication",
        extraction_text: extraction_text,
        extraction_index: 0
      }

      aligned = Alignment.align_extraction(extraction, source_encoding)

      assert aligned.alignment_status == :exact
      assert aligned.char_interval == %CharInterval{start_pos: 34, end_pos: 46}
      assert CharInterval.extract(source_text, aligned.char_interval) == "aspirin 81mg"
    end
  end
end
