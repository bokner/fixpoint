defmodule CPSolverTest.SpacePropagation do
  use ExUnit.Case

  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Propagator.NotEqual
  alias CPSolver.ConstraintStore
  alias CPSolver.Space.Propagation

  test "Propagation on stable space" do
    %{propagators: propagators, variables: variables} = stable_setup()
    {:stable, _propagators} = Propagation.run(propagators, variables)
    ## TODO
  end

  test "Propagation on solvable space" do
    %{propagators: propagators, variables: variables} = solved_setup()
    assert :solved == Propagation.run(propagators, variables)
    assert Enum.all?(variables, fn var -> Variable.fixed?(var) end)
  end

  test "Propagation on failed space" do
    %{propagators: propagators, variables: variables} = fail_setup()
    assert :fail == Propagation.run(propagators, variables)
  end

  defp stable_setup() do
    x = 1..1
    y = -5..5
    z = 0..1

    space_setup(x, y, z)
  end

  defp solved_setup() do
    x = 1..1
    y = 0..2
    z = 0..1

    space_setup(x, y, z)
  end

  defp fail_setup() do
    x = 1..1
    y = 0..1
    z = 0..1

    space_setup(x, y, z)
  end

  defp space_setup(x, y, z) do
    variables =
      Enum.map([{x, "x"}, {y, "y"}, {z, "z"}], fn {d, name} -> Variable.new(d, name: name) end)

    {:ok, [x_var, y_var, z_var] = bound_vars, _store} =
      ConstraintStore.create_store(variables)

    propagators =
      Enum.map(
        [{x_var, y_var}, {y_var, z_var}, {x_var, z_var}],
        fn {v1, v2} -> NotEqual.new([v1, v2]) end
      )

    %{propagators: propagators, variables: bound_vars}
  end
end
