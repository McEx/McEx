defmodule McEx.Mixfile do
  use Mix.Project

  def project do
    [app: :mc_ex,
     version: "0.0.1",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :cutkey, :httpotion],
     mod: {McEx, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [{:gpb, github: "tomas-abrahamsson/gpb"},
     {:poison, "~> 1.4.0"},
     {:cutkey, github: "imtal/cutkey"},
     {:ibrowse, github: "cmullaparthi/ibrowse"},
     {:httpotion, "~> 2.1.0"}]
  end
end
