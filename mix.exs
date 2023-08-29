defmodule Cpsolver.MixProject do
  use Mix.Project

  def project do
    [
      app: :cpsolver,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:ebus, "~> 0.3", hex: :erlbus},
      {:replbug, only: :dev, git: "https://github.com/bokner/replbug.git"}
    ]
  end
end
