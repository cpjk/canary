defmodule Canary.Mixfile do
  use Mix.Project

  def project do
    [app: :canary,
     version: "1.1.1",
     elixir: "~> 1.2",
     package: package(),
     description: """
     An authorization library to restrict what resources the current user is
     allowed to access, and load those resources for you.
     """,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     consolidate_protocols: false,
     docs: [extras: ["README.md"]]]
  end

  def application do
    [applications: [:logger]]
  end

  defp package do
    [maintainers: ["Chris Kelly"],
    licenses: ["MIT"],
    links: %{"GitHub" => "https://github.com/cpjk/canary"}]
  end

  defp deps do
    [
     {:ecto, ">= 1.1.0"},
     {:canada, "~> 1.0.1"},
     {:plug, "~> 1.0"},
     {:ex_doc, "~> 0.7", only: :dev},
     {:earmark, ">= 0.0.0", only: :dev},
     {:mock, ">= 0.0.0", only: :test},

     {:credo, "~> 0.5", only: [:dev, :test]}
    ]
  end
end
