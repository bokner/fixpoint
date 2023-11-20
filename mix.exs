defmodule CPSolver.MixProject do
  use Mix.Project

  def project do
    [
      app: :fixpoint,
      version: "0.5.4",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
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
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false},
      {:replbug, "~> 1.0.2", only: :dev}
    ]
  end

  defp description() do
    "Constraint Programming Solver"
  end

  defp package() do
    [
      # This option is only needed when you don't want to use the OTP application name
      name: "fixpoint",
      # These are the default files included in the package
      files: ~w(lib test data .formatter.exs mix.exs README* LICENSE*
                ),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/bokner/cpsolver"}
    ]
  end
end
