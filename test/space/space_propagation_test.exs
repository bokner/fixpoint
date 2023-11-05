defmodule CPSolverTest.SpacePropagation do
  use ExUnit.Case

  alias CPSolver.IntVariable
  alias CPSolver.Propagator.NotEqual
  alias CPSolver.ConstraintStore
  alias CPSolver.Space.Propagation

  test "Stable space" do
    %{propagators: propagators, variables: variables} = stable_setup()
    Propagation.run(propagators, variables)
  end

  defp stable_setup() do
    x = 1..1
    y = -5..5
    z = 0..0

    variables =
      Enum.map([{x, "x"}, {y, "y"}, {z, "z"}], fn {d, name} -> IntVariable.new(d, name: name) end)

    {:ok, [x_var, y_var, z_var] = bound_vars, store} =
      ConstraintStore.create_store(variables)

    propagators =
      Enum.map(
        [{x_var, y_var}, {y_var, z_var}, {x_var, z_var}],
        fn {v1, v2} -> NotEqual.new([v1, v2]) end
      )

    %{propagators: propagators, variables: bound_vars}
  end
end
