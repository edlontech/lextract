defmodule LeXtract.IntegrationTest do
  use ExUnit.Case, async: false

  @moduletag :integration
  @moduletag timeout: 120_000

  alias LeXtract.AnnotatedDocument

  setup_all do
    api_key = System.get_env("OPENAI_API_KEY")

    if is_nil(api_key) or api_key == "" do
      {:skip, "OPENAI_API_KEY not set - skipping integration tests"}
    else
      {:ok, api_key: api_key}
    end
  end

  describe "extract/2 with OpenAI" do
    @tag :openai
    test "basic entity extraction with inline template", %{api_key: api_key} do
      text = "Dr. Sarah Johnson prescribed aspirin 100mg to treat the patient's headache."

      {:ok, stream} =
        LeXtract.extract(
          text,
          prompt: "Extract medication entities from clinical text",
          examples: [
            %{
              text: "Patient takes ibuprofen 200mg for pain",
              extractions: [
                %{
                  extraction_class: "Medication",
                  name: "ibuprofen",
                  dosage: "200mg",
                  purpose: "pain"
                }
              ]
            }
          ],
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: api_key,
          temperature: 0.0
        )

      results = Enum.to_list(stream)

      assert length(results) == 1
      [doc] = results

      assert %AnnotatedDocument{} = doc
      assert doc.text == text
      assert is_list(doc.extractions)
      assert doc.extractions != []

      aspirin_extraction =
        Enum.find(doc.extractions, fn ext ->
          ext.extraction_class == "Medication" and
            (ext.extraction_text == "aspirin" or
               (is_map(ext.attributes) and Map.get(ext.attributes, "name") == "aspirin"))
        end)

      assert aspirin_extraction != nil
    end

    @tag :openai
    test "multi-class entity extraction", %{api_key: api_key} do
      text = "John Smith visited Dr. Jane Doe at Memorial Hospital on January 15th, 2024."

      {:ok, stream} =
        LeXtract.extract(
          text,
          prompt: "Extract people, locations, and dates from the text",
          examples: [
            %{
              text: "Mary Jones went to Boston Medical Center on May 1st",
              extractions: [
                %{extraction_class: "Person", name: "Mary Jones"},
                %{extraction_class: "Location", name: "Boston Medical Center"},
                %{extraction_class: "Date", value: "May 1st"}
              ]
            }
          ],
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: api_key,
          temperature: 0.0
        )

      results = Enum.to_list(stream)

      assert length(results) == 1
      [doc] = results

      assert doc.text == text
      assert length(doc.extractions) >= 2

      classes = Enum.map(doc.extractions, & &1.extraction_class) |> Enum.uniq()
      assert "Person" in classes or "Location" in classes or "Date" in classes
    end

    @tag :openai
    test "extraction with structured output mode", %{api_key: api_key} do
      text = "The patient has hypertension and type 2 diabetes mellitus."

      {:ok, stream} =
        LeXtract.extract(
          text,
          prompt: "Extract medical conditions with their types",
          examples: [
            %{
              text: "Patient diagnosed with asthma and pneumonia",
              extractions: [
                %{extraction_class: "Condition", name: "asthma", type: "chronic"},
                %{extraction_class: "Condition", name: "pneumonia", type: "acute"}
              ]
            }
          ],
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: api_key,
          use_structured_output: true,
          temperature: 0.0
        )

      results = Enum.to_list(stream)

      assert length(results) == 1
      [doc] = results

      assert doc.text == text
      assert doc.extractions != []

      condition_extractions =
        Enum.filter(doc.extractions, &(&1.extraction_class == "Condition"))

      assert condition_extractions != []
    end

    @tag :openai
    test "batch processing multiple documents", %{api_key: api_key} do
      documents = [
        "Patient takes metformin 500mg daily.",
        "Prescribed lisinopril 10mg for hypertension.",
        "Started amoxicillin 250mg three times daily."
      ]

      {:ok, stream} =
        LeXtract.extract(
          documents,
          prompt: "Extract medication names and dosages",
          examples: [
            %{
              text: "Patient uses aspirin 81mg",
              extractions: [
                %{extraction_class: "Medication", name: "aspirin", dosage: "81mg"}
              ]
            }
          ],
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: api_key,
          batch_size: 2,
          temperature: 0.0
        )

      results = Enum.to_list(stream)

      assert length(results) == 3

      Enum.each(results, fn doc ->
        assert %AnnotatedDocument{} = doc
        assert is_binary(doc.text)
        assert is_list(doc.extractions)
      end)

      total_extractions =
        results
        |> Enum.map(&length(&1.extractions))
        |> Enum.sum()

      assert total_extractions >= 2
    end

    @tag :openai
    test "chunking large documents", %{api_key: api_key} do
      large_text =
        String.duplicate(
          "The patient has diabetes. The patient takes insulin. The patient monitors glucose. ",
          20
        )

      {:ok, stream} =
        LeXtract.extract(
          large_text,
          prompt: "Extract medical conditions and medications",
          examples: [
            %{
              text: "Patient has hypertension and takes lisinopril",
              extractions: [
                %{extraction_class: "Condition", name: "hypertension"},
                %{extraction_class: "Medication", name: "lisinopril"}
              ]
            }
          ],
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: api_key,
          max_char_buffer: 500,
          chunk_overlap: 100,
          temperature: 0.0
        )

      results = Enum.to_list(stream)

      assert length(results) == 1
      [doc] = results

      assert doc.text == large_text
      assert doc.extractions != []
    end

    @tag :openai
    test "extraction with character alignment", %{api_key: api_key} do
      text = "Patient takes aspirin for headaches."

      {:ok, stream} =
        LeXtract.extract(
          text,
          prompt: "Extract medications from text",
          examples: [
            %{
              text: "Uses ibuprofen daily",
              extractions: [
                %{extraction_class: "Medication", extraction_text: "ibuprofen"}
              ]
            }
          ],
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: api_key,
          temperature: 0.0
        )

      results = Enum.to_list(stream)

      assert length(results) == 1
      [doc] = results

      med_extractions =
        Enum.filter(doc.extractions, &(&1.extraction_class == "Medication"))

      if med_extractions != [] do
        extraction = hd(med_extractions)

        if extraction.char_interval do
          assert extraction.char_interval.start_pos >= 0
          assert extraction.char_interval.end_pos > extraction.char_interval.start_pos
          assert extraction.char_interval.end_pos <= String.length(text)
        end
      end
    end

    @tag :openai
    test "error handling for invalid configuration" do
      result =
        LeXtract.extract(
          "Sample text",
          prompt: "Extract entities",
          provider: :openai
        )

      assert {:error, error} = result
      assert Exception.message(error) =~ "model"
    end

    @tag :openai
    test "error handling for missing template options" do
      result =
        LeXtract.extract(
          "Sample text",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )

      assert {:error, error} = result
      assert Exception.message(error) =~ "template"
    end

    @tag :openai
    test "error handling for conflicting template options" do
      result =
        LeXtract.extract(
          "Sample text",
          prompt: "Extract",
          template_file: "/tmp/nonexistent.yaml",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "test-key"
        )

      assert {:error, error} = result
      assert Exception.message(error) =~ "Cannot specify both"
    end
  end

  describe "extract!/2" do
    @tag :openai
    test "returns stream on success", %{api_key: api_key} do
      stream =
        LeXtract.extract!(
          "Test text",
          prompt: "Extract entities",
          examples: [],
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: api_key
        )

      assert is_struct(stream, Stream)
      results = Enum.to_list(stream)
      assert length(results) == 1
    end

    @tag :openai
    test "raises on error" do
      assert_raise LeXtract.Error.Invalid.Config, fn ->
        LeXtract.extract!(
          "Test text",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "key"
        )
      end
    end
  end

  describe "extract_from_file/2" do
    @tag :openai
    test "extracts from file content", %{api_key: api_key} do
      file_path = "/tmp/test_extraction_#{:rand.uniform(10000)}.txt"
      content = "Patient has diabetes and takes metformin."

      try do
        File.write!(file_path, content)

        {:ok, stream} =
          LeXtract.extract_from_file(
            file_path,
            prompt: "Extract medical entities",
            examples: [],
            model: "gpt-4o-mini",
            provider: :openai,
            api_key: api_key
          )

        results = Enum.to_list(stream)

        assert length(results) == 1
        [doc] = results
        assert doc.text == content
      after
        File.rm(file_path)
      end
    end

    @tag :openai
    test "handles file read errors" do
      {:error, error} =
        LeXtract.extract_from_file(
          "/nonexistent/file.txt",
          prompt: "Extract",
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: "key"
        )

      assert %LeXtract.Error.External.TemplateRead{} = error
    end
  end

  describe "template file integration" do
    @tag :openai
    test "extracts using YAML template file", %{api_key: api_key} do
      template_path = "/tmp/test_template_#{:rand.uniform(10000)}.yaml"

      template_content = """
      description: Extract medication entities with dosage
      examples:
        - text: "Patient takes aspirin 100mg daily"
          extractions:
            - extraction_class: Medication
              name: aspirin
              dosage: 100mg
              frequency: daily
      """

      try do
        File.write!(template_path, template_content)

        {:ok, stream} =
          LeXtract.extract(
            "Doctor prescribed ibuprofen 200mg twice daily.",
            template_file: template_path,
            model: "gpt-4o-mini",
            provider: :openai,
            api_key: api_key,
            temperature: 0.0
          )

        results = Enum.to_list(stream)

        assert length(results) == 1
        [doc] = results

        assert doc.extractions != []
      after
        File.rm(template_path)
      end
    end

    @tag :openai
    test "extracts using JSON template file", %{api_key: api_key} do
      template_path = "/tmp/test_template_#{:rand.uniform(10000)}.json"

      template_content = """
      {
        "description": "Extract person names from text",
        "examples": [
          {
            "text": "John Smith and Mary Jones attended",
            "extractions": [
              {"extraction_class": "Person", "name": "John Smith"},
              {"extraction_class": "Person", "name": "Mary Jones"}
            ]
          }
        ]
      }
      """

      try do
        File.write!(template_path, template_content)

        {:ok, stream} =
          LeXtract.extract(
            "Dr. Sarah Johnson met with patient Robert Williams.",
            template_file: template_path,
            model: "gpt-4o-mini",
            provider: :openai,
            api_key: api_key,
            temperature: 0.0
          )

        results = Enum.to_list(stream)

        assert length(results) == 1
        [doc] = results

        person_extractions = Enum.filter(doc.extractions, &(&1.extraction_class == "Person"))
        assert person_extractions != []
      after
        File.rm(template_path)
      end
    end
  end

  describe "validate_options/1" do
    test "validates correct options" do
      {:ok, validated} =
        LeXtract.validate_options(
          prompt: "Extract entities",
          max_char_buffer: 2000
        )

      assert Keyword.get(validated, :prompt) == "Extract entities"
      assert Keyword.get(validated, :format) == :yaml
      assert Keyword.get(validated, :max_char_buffer) == 2000
    end

    test "returns error when no template configuration is provided" do
      {:error, error} =
        LeXtract.validate_options([])

      assert Exception.message(error) =~ "template"
    end

    test "returns error for invalid types" do
      {:error, error} =
        LeXtract.validate_options(
          prompt: "Extract",
          max_char_buffer: "invalid"
        )

      assert Exception.message(error) =~ "max_char_buffer"
    end

    test "returns error for invalid format" do
      {:error, error} =
        LeXtract.validate_options(
          prompt: "Extract",
          format: :xml
        )

      assert Exception.message(error) =~ "format"
    end
  end

  describe "real-world extraction scenarios" do
    @tag :openai
    test "medical entity extraction from clinical notes", %{api_key: api_key} do
      clinical_note = """
      Patient: John Doe
      Date: 2024-01-15

      Chief Complaint: Chest pain and shortness of breath

      History of Present Illness:
      65-year-old male presents with chest pain radiating to left arm.
      Patient has history of hypertension and type 2 diabetes mellitus.

      Current Medications:
      - Metformin 1000mg twice daily
      - Lisinopril 20mg once daily
      - Atorvastatin 40mg at bedtime

      Assessment:
      Possible acute coronary syndrome. Patient admitted for further evaluation.
      """

      {:ok, stream} =
        LeXtract.extract(
          clinical_note,
          prompt: "Extract medical conditions and medications from clinical notes",
          examples: [
            %{
              text:
                "Patient has asthma and takes albuterol 90mcg as needed for wheezing episodes.",
              extractions: [
                %{extraction_class: "Condition", name: "asthma"},
                %{
                  extraction_class: "Medication",
                  name: "albuterol",
                  dosage: "90mcg",
                  frequency: "as needed"
                }
              ]
            }
          ],
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: api_key,
          max_char_buffer: 2000,
          temperature: 0.0
        )

      results = Enum.to_list(stream)

      assert length(results) == 1
      [doc] = results

      assert length(doc.extractions) >= 3

      conditions = Enum.filter(doc.extractions, &(&1.extraction_class == "Condition"))
      medications = Enum.filter(doc.extractions, &(&1.extraction_class == "Medication"))

      assert conditions != []
      assert medications != []
    end

    @tag :openai
    test "named entity recognition from news text", %{api_key: api_key} do
      news_text = """
      Apple Inc. announced today that CEO Tim Cook will speak at the World Economic Forum
      in Davos, Switzerland next month. The company's stock rose 2.3% on the NASDAQ exchange
      following the announcement. Microsoft and Google representatives will also attend the event.
      """

      {:ok, stream} =
        LeXtract.extract(
          news_text,
          prompt: "Extract organizations, people, and locations",
          examples: [
            %{
              text: "Amazon CEO Jeff Bezos visited Seattle headquarters",
              extractions: [
                %{extraction_class: "Organization", name: "Amazon"},
                %{extraction_class: "Person", name: "Jeff Bezos"},
                %{extraction_class: "Location", name: "Seattle"}
              ]
            }
          ],
          model: "gpt-4o-mini",
          provider: :openai,
          api_key: api_key,
          temperature: 0.0
        )

      results = Enum.to_list(stream)

      assert length(results) == 1
      [doc] = results

      orgs = Enum.filter(doc.extractions, &(&1.extraction_class == "Organization"))
      assert orgs != []
    end
  end
end
