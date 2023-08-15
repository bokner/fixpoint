defmodule CPSolverTest.Space do
  use ExUnit.Case

  import ExUnit.CaptureLog
  import CPSolver.Test.Helpers

  describe "Computation space" do
    alias CPSolver.Store.Registry, as: Store
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Space, as: Space
    alias CPSolver.Propagator.NotEqual

    test "create space" do
      x_values = 1..10
      y_values = -5..5
      z_values = 0..2
      values = [x_values, y_values, z_values]
      [x, y, z] = variables = Enum.map(values, fn d -> Variable.new(d) end)
      propagators = [{NotEqual, [x, y]}, {NotEqual, [y, z]}]
      {:ok, space} = Space.create(variables, propagators)

      {state, %{propagators: space_propagators, variables: space_variables} = _data} =
        Space.get_state_and_data(space)

      assert state == :propagating
      assert length(propagators) == length(space_propagators)
      assert length(variables) == length(space_variables)
    end
  end
end
