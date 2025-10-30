defmodule LeXtract.MixProject do
  use Mix.Project

  def project do
    [
      app: :lextract,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {LeXtract.Application, []}
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true},
      {:mimic, "~> 2.0", only: :test},
      {:nimble_options, "~> 1.1"},
      {:req_llm, "~> 1.0.0-rc.8"},
      {:splode, "~> 0.2.9"},
      {:text_chunker, "~> 0.5.2"},
      {:tokenizers, "~> 0.5.1"},
      {:uuid_v7, "~> 0.6.0"},
      {:yaml_elixir, "~> 2.11"},
      {:zoi, "~> 0.7.0"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
