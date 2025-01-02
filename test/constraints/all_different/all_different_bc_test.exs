defmodule CPSolverTest.Constraint.AllDifferent.BC do
  use ExUnit.Case, async: false

  describe "AllDifferent" do
    alias CPSolver.Constraint.AllDifferent.BC, as: AllDifferent
    alias CPSolver.Propagator.AllDifferent.BC, as: BCPropagator
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Constraint
    alias CPSolver.Model
    import CPSolver.Variable.View.Factory
    alias CPSolver.Utils

    test "all fixed" do
      variables = Enum.map(1..5, fn i -> Variable.new(i) end)
      model = Model.new(variables, [Constraint.new(AllDifferent, variables)])
      {:ok, result} = CPSolver.solve(model)

      assert hd(result.solutions) == [1, 2, 3, 4, 5]
      assert result.statistics.solution_count == 1
    end

    test "reduction" do
      minizinc_solutions = [[1, 2, 4, 5], [1, 2, 3, 4], [1, 2, 3, 5]]
      variables = Enum.map([1, 1..2, 1..4, [1, 2, 4, 5]], fn d -> Variable.new(d) end)
      model = Model.new(variables, [Constraint.new(AllDifferent, variables)])
      {:ok, result} = CPSolver.solve(model)
      assert Enum.sort(result.solutions) == Enum.sort(minizinc_solutions)
    end

    test "reduction (Puget example)" do
      vars =
        Enum.map(
          [{:x1, 3..4}, {:x2, 2..4}, {:x3, 3..4}, {:x4, 2..5}, {:x5, 3..6}, {:x6, 1..6}],
          fn {name, d} -> Variable.new(d, name: name) end
        )

      BCPropagator.filter(BCPropagator.arguments(vars), nil, nil)
      reduced_domains = Enum.map(vars, fn v -> Utils.domain_values(v) end)

      assert reduced_domains == [
               MapSet.new([3, 4]),
               MapSet.new([2]),
               MapSet.new([3, 4]),
               MapSet.new([5]),
               MapSet.new([6]),
               MapSet.new([1])
             ]
    end

    test "produces all possible permutations" do
      domain = 1..3
      variables = Enum.map(1..3, fn _ -> Variable.new(domain) end)

      model = Model.new(variables, [Constraint.new(AllDifferent, variables)])

      {:ok, result} = CPSolver.solve(model, timeout: 100, search: {:first_fail, :indomain_split})

      assert result.statistics.solution_count == 6

      assert result.solutions |> Enum.sort() == [
               [1, 2, 3],
               [1, 3, 2],
               [2, 1, 3],
               [2, 3, 1],
               [3, 1, 2],
               [3, 2, 1]
             ]
    end

    test "unsatisfiable (duplicates)" do
      variables = Enum.map(1..3, fn _ -> Variable.new(1) end)
      model = Model.new(variables, [Constraint.new(AllDifferent, variables)])

      {:ok, result} = CPSolver.solve(model, timeout: 1000)

      assert result.status == :unsatisfiable
    end

    test "unsatisfiable(pigeonhole)" do
      variables = Enum.map(1..4, fn _ -> Variable.new(1..3) end)
      model = Model.new(variables, [Constraint.new(AllDifferent, variables)])

      {:ok, result} = CPSolver.solve(model)

      assert result.status == :unsatisfiable
    end

    test "views in variable list" do
      n = 3
      variables = Enum.map(1..n, fn i -> Variable.new(1..n, name: "row#{i}") end)

      diagonal_down =
        Enum.map(Enum.with_index(variables, 1), fn {var, idx} -> linear(var, 1, -idx) end)

      diagonal_up =
        Enum.map(Enum.with_index(variables, 1), fn {var, idx} -> linear(var, 1, idx) end)

      model =
        Model.new(
          variables,
          [
            Constraint.new(AllDifferent, diagonal_down),
            Constraint.new(AllDifferent, diagonal_up),
            Constraint.new(AllDifferent, variables)
          ]
        )

      {:ok, res} = CPSolver.solve(model)

      assert res.status == :unsatisfiable
    end
  end
end
