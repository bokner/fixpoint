defmodule CPSolver.Constraint.Channel do
  @moduledoc """
  `Channel` constraint.
  Given an array of boolean variables `b` and an integer variable `x`,
  (b[i] = true) iff (x = i)
  """
  use CPSolver.Constraint

  def new(x, b) do
    new([x | b])
  end

  @impl true
  def propagators(args) do
    [
      CPSolver.Propagator.Channel.new(args)
    ]
  end

end
