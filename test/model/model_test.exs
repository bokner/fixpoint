defmodule CpSolverTest.Model do
  use ExUnit.Case
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Model
  alias CPSolver.Objective
  alias CPSolver.Variable.Interface

  describe "Model" do
    alias CPSolver.Constraint.{LessOrEqual, Sum}

    test "create" do
      sum_bound = 1000
      x_bound = 100
      y_bound = 200
      x = Variable.new(1..x_bound, name: "x")
      y = Variable.new(1..y_bound, name: "y")
      z = Variable.new(1..sum_bound)

      variables = [x, y]
      constraints = [LessOrEqual.new(x, y), Sum.new(z, [x, y])]

      model =
        Model.new(
          variables,
          constraints,
          objective: Objective.minimize(z)
        )

      ## Additional variable z is pulled from the Sum constraints
      assert length(model.variables) == 3
      ## All variables are indexed starting from 1
      assert Enum.all?(Enum.with_index(model.variables, 1), fn {var, idx} -> var.index == idx end)
      ## The variable in the objective has the same index as the variable in the all_vars list
      assert model.objective.variable |> Interface.variable() |> Map.get(:index) == 3
    end
  end
end
