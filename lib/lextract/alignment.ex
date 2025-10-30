defmodule LeXtract.Alignment do
  require Logger

  @moduledoc """
  Aligns extracted entities back to their positions in source text.

  This module provides token-based text alignment for matching extracted text
  (which may be paraphrased or slightly modified by LLMs) back to the original
  source text positions. It uses multiple matching strategies with fallback to
  handle various text transformation scenarios.

  ## Matching Strategies

  The alignment process uses these strategies in priority order:

  1. **Exact Match** - Perfect token sequence match (case-sensitive)
  2. **Case-Insensitive Match** - Lowercase token comparison
  3. **Fuzzy Match** - Jaro distance-based similarity matching for minor variations
  4. **Partial Match** - Substring/contains matching
  5. **No Match** - Returns nil when no match is found

  ## Examples

      iex> extraction = %LeXtract.Extraction{
      ...>   extraction_class: "person",
      ...>   extraction_text: "John Doe",
      ...>   extraction_index: 0
      ...> }
      iex> {:ok, source_encoding} = LeXtract.Tokenizer.tokenize("The patient John Doe was prescribed...")
      iex> aligned = LeXtract.Alignment.align_extraction(extraction, source_encoding)
      iex> aligned.alignment_status
      :exact

      iex> extraction = %LeXtract.Extraction{
      ...>   extraction_class: "person",
      ...>   extraction_text: "JOHN DOE",
      ...>   extraction_index: 0
      ...> }
      iex> {:ok, source_encoding} = LeXtract.Tokenizer.tokenize("Patient: john doe")
      iex> aligned = LeXtract.Alignment.align_extraction(extraction, source_encoding)
      iex> aligned.alignment_status
      :exact

  """

  alias LeXtract.{AlignmentStatus, CharInterval, Extraction, Tokenizer}

  @type encoding :: Tokenizer.encoding()
  @type match_result :: %{
          char_interval: CharInterval.t(),
          alignment_status: AlignmentStatus.t()
        }

  @doc """
  Aligns an extraction to its position in the source text.

  Takes an extraction and source encoding, attempts to find the extraction text
  in the source using multiple matching strategies, and returns an updated
  extraction with character interval and alignment status.

  ## Parameters

    * `extraction` - The extraction to align
    * `source_encoding` - Token encoding of the source text from `Tokenizer.tokenize/1`

  ## Options

    * `:fuzzy_threshold` - Minimum Jaro similarity for fuzzy matching, 0.0-1.0 (default: 0.85)
    * `:min_partial_length` - Minimum token overlap for partial matching (default: 2)
    * `:max_text_length` - Maximum allowed extraction text length (default: 10_000)

  ## Returns

  Returns an updated `%Extraction{}` with `char_interval` and `alignment_status`
  fields populated. If no match is found, returns the extraction with
  `alignment_status: :none` and `char_interval: nil`.

  ## Examples

      iex> extraction = %LeXtract.Extraction{
      ...>   extraction_class: "medication",
      ...>   extraction_text: "aspirin",
      ...>   extraction_index: 0
      ...> }
      iex> {:ok, encoding} = LeXtract.Tokenizer.tokenize("Patient takes aspirin daily")
      iex> aligned = LeXtract.Alignment.align_extraction(extraction, encoding)
      iex> aligned.char_interval
      %LeXtract.CharInterval{start_pos: 14, end_pos: 21}
      iex> aligned.alignment_status
      :exact

  """
  @spec align_extraction(Extraction.t(), encoding(), keyword()) :: Extraction.t()
  def align_extraction(%Extraction{} = extraction, source_encoding, opts \\ []) do
    extraction_text = extraction.extraction_text || ""
    extraction_index = max(extraction.extraction_index || 0, 0)
    max_length = Keyword.get(opts, :max_text_length, 10_000)

    cond do
      extraction_text == "" ->
        %{extraction | char_interval: nil, alignment_status: :none}

      String.length(extraction_text) > max_length ->
        %{extraction | char_interval: nil, alignment_status: :none}

      true ->
        case find_match(extraction_text, source_encoding, extraction_index, opts) do
          nil ->
            %{extraction | char_interval: nil, alignment_status: :none}

          %{char_interval: interval, alignment_status: status} ->
            %{extraction | char_interval: interval, alignment_status: status}
        end
    end
  end

  @doc """
  Finds a match for extraction text in source encoding using multiple strategies.

  Attempts to find the extraction text in the source text using various matching
  strategies. The `occurrence_index` parameter allows selecting a specific
  occurrence when the text appears multiple times (0-based).

  ## Parameters

    * `extraction_text` - The text to find in the source
    * `source_encoding` - Token encoding of the source text
    * `occurrence_index` - Which occurrence to match (0-based, default: 0)
    * `opts` - Options (see `align_extraction/3`)

  ## Returns

  Returns a map with `:char_interval` and `:alignment_status`, or `nil` if no
  match is found.

  ## Examples

      iex> {:ok, encoding} = LeXtract.Tokenizer.tokenize("John loves John")
      iex> LeXtract.Alignment.find_match("John", encoding, 0)
      %{char_interval: %LeXtract.CharInterval{start_pos: 0, end_pos: 4}, alignment_status: :exact}

      iex> {:ok, encoding} = LeXtract.Tokenizer.tokenize("John loves John")
      iex> result = LeXtract.Alignment.find_match("John", encoding, 1)
      iex> result.char_interval.start_pos
      11

  """
  @spec find_match(String.t(), encoding(), non_neg_integer(), keyword()) ::
          match_result() | nil
  def find_match(extraction_text, source_encoding, occurrence_index \\ 0, opts \\ [])
      when is_binary(extraction_text) and is_integer(occurrence_index) and occurrence_index >= 0 do
    if extraction_text == "" do
      nil
    else
      case Tokenizer.tokenize(extraction_text) do
        {:ok, extraction_encoding} ->
          try_all_strategies(extraction_encoding, source_encoding, occurrence_index, opts)

        {:error, reason} ->
          Logger.warning("Tokenization failed for extraction text: #{inspect(reason)}")
          nil
      end
    end
  end

  defp try_all_strategies(extraction_encoding, source_encoding, occurrence_index, opts) do
    strategies = [
      {:exact, &try_exact_match/4},
      {:exact, &try_case_insensitive_match/4},
      {:fuzzy, &try_fuzzy_match/4},
      {:partial, &try_partial_match/4}
    ]

    Enum.find_value(strategies, fn {status, strategy_fn} ->
      apply_strategy(
        strategy_fn,
        extraction_encoding,
        source_encoding,
        occurrence_index,
        opts,
        status
      )
    end)
  end

  defp apply_strategy(
         strategy_fn,
         extraction_encoding,
         source_encoding,
         occurrence_index,
         opts,
         status
       ) do
    case strategy_fn.(
           extraction_encoding,
           source_encoding,
           occurrence_index,
           opts
         ) do
      nil -> nil
      char_interval -> %{char_interval: char_interval, alignment_status: status}
    end
  end

  @doc """
  Searches for a token sequence in source tokens.

  Helper function that finds all occurrences of a token sequence and returns
  the character interval for a specific occurrence.

  ## Parameters

    * `needle_tokens` - Token sequence to search for
    * `haystack_tokens` - Source token sequence to search in
    * `source_encoding` - Source encoding for offset mapping
    * `occurrence_index` - Which occurrence to return (0-based)
    * `opts` - Matching options

  ## Returns

  Returns a `%CharInterval{}` for the requested occurrence, or `nil` if not found.
  """
  @spec search_tokens([String.t()], [String.t()], encoding(), non_neg_integer(), keyword()) ::
          CharInterval.t() | nil
  def search_tokens(
        needle_tokens,
        haystack_tokens,
        source_encoding,
        occurrence_index \\ 0,
        opts \\ []
      )

  def search_tokens([], _haystack_tokens, _source_encoding, _occurrence_index, _opts), do: nil

  def search_tokens(needle_tokens, haystack_tokens, source_encoding, occurrence_index, opts) do
    case_sensitive = Keyword.get(opts, :case_sensitive, false)

    if case_sensitive do
      # For case-sensitive, we need to compare the original text strings
      # since the tokenizer may lowercase tokens (like BERT)
      case get_source_text(source_encoding) do
        {:ok, source_text} ->
          search_case_sensitive_in_text(
            needle_tokens,
            haystack_tokens,
            source_text,
            source_encoding,
            occurrence_index
          )

        _ ->
          nil
      end
    else
      # Case-insensitive: compare lowercased tokens
      haystack = Enum.map(haystack_tokens, &String.downcase/1)
      needle = Enum.map(needle_tokens, &String.downcase/1)

      needle
      |> find_all_occurrences(haystack, 0, [])
      |> Enum.at(occurrence_index)
      |> case do
        nil -> nil
        start_idx -> token_span_to_char_interval(start_idx, length(needle), source_encoding)
      end
    end
  end

  defp search_case_sensitive_in_text(
         needle_tokens,
         haystack_tokens,
         source_text,
         source_encoding,
         occurrence_index
       ) do
    haystack_lower = Enum.map(haystack_tokens, &String.downcase/1)
    needle_lower = Enum.map(needle_tokens, &String.downcase/1)

    needle_lower
    |> find_all_occurrences(haystack_lower, 0, [])
    |> Enum.map(fn start_idx ->
      with interval <-
             token_span_to_char_interval(start_idx, length(needle_tokens), source_encoding),
           true <- interval != nil do
        extracted_text = CharInterval.extract(source_text, interval)
        needle_text = reconstruct_text_from_tokens(needle_tokens)

        if extracted_text == needle_text do
          {start_idx, interval}
        else
          nil
        end
      else
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.at(occurrence_index)
    |> case do
      nil -> nil
      {_idx, interval} -> interval
    end
  end

  defp try_exact_match(
         extraction_encoding,
         source_encoding,
         occurrence_index,
         _opts
       ) do
    extraction_ids = strip_special_tokens(extraction_encoding.ids)
    source_ids = strip_special_tokens(source_encoding.ids)

    if Enum.empty?(extraction_ids) do
      nil
    else
      special_token_offset = count_leading_special_tokens(source_encoding)

      extraction_ids
      |> find_all_id_occurrences(source_ids, 0, [])
      |> Enum.at(occurrence_index)
      |> case do
        nil ->
          nil

        stripped_idx ->
          actual_idx = stripped_idx + special_token_offset
          token_span_to_char_interval(actual_idx, length(extraction_ids), source_encoding)
      end
    end
  end

  defp try_case_insensitive_match(
         extraction_encoding,
         source_encoding,
         occurrence_index,
         _opts
       ) do
    extraction_tokens = strip_special_tokens(extraction_encoding.tokens)
    source_tokens = strip_special_tokens(source_encoding.tokens)

    if Enum.empty?(extraction_tokens) do
      nil
    else
      special_token_offset = count_leading_special_tokens(source_encoding)

      extraction_lower = Enum.map(extraction_tokens, &String.downcase/1)
      source_lower = Enum.map(source_tokens, &String.downcase/1)

      extraction_lower
      |> find_all_occurrences(source_lower, 0, [])
      |> Enum.at(occurrence_index)
      |> case do
        nil ->
          nil

        stripped_idx ->
          actual_idx = stripped_idx + special_token_offset
          token_span_to_char_interval(actual_idx, length(extraction_tokens), source_encoding)
      end
    end
  end

  defp try_fuzzy_match(
         extraction_encoding,
         source_encoding,
         occurrence_index,
         opts
       ) do
    threshold = Keyword.get(opts, :fuzzy_threshold, 0.85)
    extraction_tokens = strip_special_tokens(extraction_encoding.tokens)
    source_tokens = strip_special_tokens(source_encoding.tokens)
    needle_length = length(extraction_tokens)

    if needle_length == 0 do
      nil
    else
      special_token_offset = count_leading_special_tokens(source_encoding)
      needle_str = Enum.join(extraction_tokens, " ")

      source_tokens
      |> Enum.chunk_every(needle_length, 1, :discard)
      |> find_fuzzy_matches(needle_str, threshold, occurrence_index)
      |> convert_match_to_interval(special_token_offset, needle_length, source_encoding, occurrence_index)
    end
  end

  defp find_fuzzy_matches(windows, needle_str, threshold, occurrence_index) do
    windows
    |> Enum.reduce_while({0, [], 0}, fn window, state ->
      process_fuzzy_window(window, state, needle_str, threshold, occurrence_index)
    end)
  end

  defp process_fuzzy_window(_window, {idx, matches, count}, _needle_str, _threshold, occurrence_index)
       when count > occurrence_index do
    {:halt, {idx, matches, count}}
  end

  defp process_fuzzy_window(window, {idx, matches, count}, needle_str, threshold, _occurrence_index) do
    window_str = Enum.join(window, " ")
    similarity = String.jaro_distance(needle_str, window_str)

    new_state =
      if similarity >= threshold do
        {idx + 1, [idx | matches], count + 1}
      else
        {idx + 1, matches, count}
      end

    {:cont, new_state}
  end

  defp convert_match_to_interval(
         {_final_idx, matches, _count},
         special_token_offset,
         needle_length,
         source_encoding,
         occurrence_index
       ) do
    matches
    |> Enum.reverse()
    |> Enum.at(occurrence_index)
    |> case do
      nil ->
        nil

      stripped_idx ->
        actual_idx = stripped_idx + special_token_offset
        token_span_to_char_interval(actual_idx, needle_length, source_encoding)
    end
  end

  defp try_partial_match(
         extraction_encoding,
         source_encoding,
         occurrence_index,
         opts
       ) do
    min_overlap = Keyword.get(opts, :min_partial_length, 2)
    extraction_tokens = strip_special_tokens(extraction_encoding.tokens)
    source_tokens = strip_special_tokens(source_encoding.tokens)
    needle_length = length(extraction_tokens)

    if needle_length < min_overlap do
      nil
    else
      special_token_offset = count_leading_special_tokens(source_encoding)

      extraction_set = MapSet.new(Enum.map(extraction_tokens, &String.downcase/1))

      source_tokens
      |> Enum.map(&String.downcase/1)
      |> Enum.chunk_every(needle_length, 1, :discard)
      |> Enum.with_index()
      |> Enum.filter(fn {window, _idx} ->
        window_set = MapSet.new(window)
        overlap = MapSet.intersection(extraction_set, window_set) |> MapSet.size()
        overlap >= min_overlap
      end)
      |> Enum.at(occurrence_index)
      |> case do
        nil ->
          nil

        {_window, stripped_idx} ->
          actual_idx = stripped_idx + special_token_offset
          token_span_to_char_interval(actual_idx, needle_length, source_encoding)
      end
    end
  end

  defp find_all_occurrences(needle, haystack, start_idx, acc)
       when start_idx + length(needle) <= length(haystack) do
    slice = Enum.slice(haystack, start_idx, length(needle))

    new_acc =
      if slice == needle do
        [start_idx | acc]
      else
        acc
      end

    find_all_occurrences(needle, haystack, start_idx + 1, new_acc)
  end

  defp find_all_occurrences(_needle, _haystack, _start_idx, acc) do
    Enum.reverse(acc)
  end

  defp find_all_id_occurrences(needle, haystack, start_idx, acc)
       when start_idx + length(needle) <= length(haystack) do
    slice = Enum.slice(haystack, start_idx, length(needle))

    new_acc =
      if slice == needle do
        [start_idx | acc]
      else
        acc
      end

    find_all_id_occurrences(needle, haystack, start_idx + 1, new_acc)
  end

  defp find_all_id_occurrences(_needle, _haystack, _start_idx, acc) do
    Enum.reverse(acc)
  end

  defp strip_special_tokens(tokens) when is_list(tokens) do
    tokens
    |> Enum.reject(fn token ->
      token in ["[CLS]", "[SEP]", "[PAD]"] or
        (is_integer(token) and token in [101, 102, 0])
    end)
  end

  defp count_leading_special_tokens(%{tokens: tokens}) do
    tokens
    |> Enum.take_while(fn token -> token in ["[CLS]", "[SEP]", "[PAD]"] end)
    |> length()
  end

  defp token_span_to_char_interval(start_token_idx, token_count, source_encoding) do
    end_token_idx = start_token_idx + token_count - 1

    with {start_byte, _} <- Tokenizer.get_offset(source_encoding, start_token_idx),
         {_, end_byte} <- Tokenizer.get_offset(source_encoding, end_token_idx),
         true <- start_byte <= end_byte,
         {:ok, source_text} <- get_source_text(source_encoding) do
      start_char = byte_to_char_position(source_text, start_byte)
      end_char = byte_to_char_position(source_text, end_byte)
      CharInterval.new(start_char, end_char)
    else
      _ -> nil
    end
  end

  defp byte_to_char_position(text, byte_pos) do
    :binary.part(text, 0, byte_pos)
    |> String.length()
  end

  defp get_source_text(%{text: text}) when is_binary(text), do: {:ok, text}
  defp get_source_text(_), do: {:error, :no_source_text}

  defp reconstruct_text_from_tokens(tokens) do
    tokens
    |> Enum.reduce([], &merge_subword_token/2)
    |> Enum.reverse()
    |> Enum.join(" ")
  end

  defp merge_subword_token(token, acc) do
    if String.starts_with?(token, "##") do
      merge_continuation_token(token, acc)
    else
      [token | acc]
    end
  end

  defp merge_continuation_token(token, [last | rest]) do
    [last <> String.trim_leading(token, "##") | rest]
  end

  defp merge_continuation_token(token, []) do
    [String.trim_leading(token, "##")]
  end
end
