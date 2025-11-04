defmodule LeXtract.MixProject do
  use Mix.Project

  def project do
    [
      app: :lextract,
      version: "0.1.1",
      description: description(),
      package: package(),
      aliases: aliases(),
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        plt_core_path: "_plts/core"
      ],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test
      ],
      source_url: "https://github.com/YgorCastor/lextract.git",
      homepage_url: "https://github.com/YgorCastor/lextract.git",
      docs: [
        main: "readme",
        extras: [
          "CHANGELOG.md": [title: "Changelog"],
          "README.md": [title: "Introduction"],
          LICENSE: [title: "License"]
        ]
      ],
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
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:dev, :test]},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true},
      {:mimic, "~> 2.0", only: :test},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:nimble_options, "~> 1.1"},
      {:req_llm, "~> 1.0"},
      {:splode, "~> 0.2"},
      {:text_chunker, "~> 0.5"},
      {:tokenizers, "~> 0.5"},
      {:uuid_v7, "~> 0.6.0"},
      {:yaml_elixir, "~> 2.11"},
      {:zoi, "~> 0.8"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.post": :test,
        "coveralls.github": :test,
        "coveralls.html": :test,
        "test.integration": :test
      ]
    ]
  end

  defp aliases do
    [
      test: ["test --exclude integration"],
      "test.integration": ["test --only integration"]
    ]
  end

  defp description() do
    "LLM-powered text extraction library for Elixir. Based on Google's LangExtract"
  end

  defp package() do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/YgorCastor/lextract.git"},
      sponsor: "ycastor.eth"
    ]
  end
end
