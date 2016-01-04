defmodule Canary.Mixfile do
  use Mix.Project

  def project do
    [app: :canary,
     version: "0.12.2",
     elixir: "~> 1.0  or ~> 1.1-beta",
     package: package,
     description: """
     An authorization library to restrict what resources the current user is
     allowed to access, and load resources for you.
     """,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
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
     { :ecto, ">= 0.10.0" },
     { :canada, "~> 1.0.0" },
     { :plug, ">= 0.11.3" },
     {:ex_doc, "~> 0.7", only: :dev},
     {:earmark, ">= 0.0.0", only: :dev},
     {:mock, ">= 0.0.0", only: :test}
    ]
  end
end
