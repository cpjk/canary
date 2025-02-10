defmodule Canary.Mixfile do
  use Mix.Project

  def project do
    [
      app: :canary,
      version: "2.0.0-dev",
      elixir: "~> 1.14",
      package: package(),
      description: """
      An authorization library to restrict what resources the current user is
      allowed to access, and load those resources for you.
      """,
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      consolidate_protocols: false,
      elixirc_paths: elixirc_paths(Mix.env()),
      test_options: [docs: true],
      test_coverage: [summary: [threshold: 85], ignore_modules: coverage_ignore_modules()],
      docs: [
        extras: [
          "docs/getting-started.md",
          "README.md",
          "CHANGELOG.md",
        ],
        groups_for_modules: [
          "Error Handler": [Canary.ErrorHandler, Canary.DefaultHandler],
        ]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [extra_applications: [:logger]]
  end

  defp package do
    [
      maintainers: ["Chris Kelly"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/cpjk/canary"}
    ]
  end

  defp deps do
    [
      {:ecto, ">= 1.1.0"},
      {:canada, "~> 2.0.0"},
      {:plug, "~> 1.10"},
      {:ex_doc, "~> 0.7", only: :dev},
      {:earmark, ">= 0.0.0", only: :dev},
      {:mock, ">= 0.0.0", only: :test},
      {:credo, "~> 1.0", only: [:dev, :test]},
      {:phoenix, "~> 1.6", optional: true},
      {:phoenix_live_view, "~> 0.20 or ~> 1.0", optional: true},
      {:floki, ">= 0.30.0", only: :test}
    ]
  end

  defp coverage_ignore_modules do
    [
      ~r/Canary\.HooksHelper\..*/
    ]
  end
end
