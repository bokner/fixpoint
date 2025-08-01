defmodule CPSolver.MixProject do
  use Mix.Project

  def project do
    [
      app: :fixpoint,
      version: "0.12.7",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      docs: docs(),
      package: package(),
      name: "Fixpoint"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {CPSolver.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:libgraph, "~> 0.16.0"},
      {:bitgraph, "~> 0.1"},
      #{:bitgraph, path: Path.join([System.get_env("HOME"), "projects", "bitgraph"])},
      {:arrays, "~> 2.1"},
      {:arrays_aja, "~> 0.2.0"},
      {:math, "~> 0.7.0", only: :test},
      {:permutation, "~> 0.1.0", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2", only: [:dev], runtime: false},
      {:ex_united, "~> 0.1.5", only: :test},
      {:local_cluster, "~> 1.2", only: :test},
      {:replbug, "~> 1.0.2", only: :dev}
    ]
  end

  defp description() do
    "Constraint Programming Solver"
  end

  defp docs do
    [
      main: "readme",
      formatter_opts: [gfm: true],
      extras: [
        "README.md"
      ]
    ]
  end

  defp package() do
    [
      # This option is only needed when you don't want to use the OTP application name
      name: "fixpoint",
      # These are the default files included in the package
      files: ~w(lib src test data .formatter.exs mix.exs README* LICENSE*
                ),
      exclude_patterns: ["misc/**", "scripts/**", "**/*._exs", "**/*._ex"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/bokner/fixpoint"}
    ]
  end
end
