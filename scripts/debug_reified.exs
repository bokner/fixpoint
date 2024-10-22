defmodule DebugReified do
  alias CPSolver.Constraint.{Reified, HalfReified, InverseHalfReified}
  alias CPSolver.Constraint.{Equal, NotEqual, LessOrEqual}
  alias CPSolver.IntVariable
  alias CPSolver.BooleanVariable
  alias CPSolver.Variable.Interface
  alias CPSolver.Model

  def run(d_x, d_y, d_b \\ [0, 1], constraint_mod \\ LessOrEqual, mode \\ :full) do
    x = IntVariable.new(d_x, name: "x")
    y = IntVariable.new(d_y, name: "y")
    b = IntVariable.new(d_b, name: "b")
    # BooleanVariable.new(name: "b")

    le_constraint = constraint_mod.new(x, y)
    model = Model.new([x, y, b], [impl(mode).new(le_constraint, b)])

    {:ok, _res} = CPSolver.solve(model, space_threads: 1)
  end

  defp impl(:full) do
    Reified
  end

  defp impl(:half) do
    HalfReified
  end

  defp impl(:inverse_half) do
    InverseHalfReified
  end
end
