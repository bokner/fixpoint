defmodule CPSolverTest.Constraint.Reified do
  use ExUnit.Case, async: false

  describe "Reification" do
    alias CPSolver.Constraint.{Reified, HalfReified, InverseHalfReified}
    alias CPSolver.Constraint.{Equal, NotEqual, LessOrEqual, Less, Absolute}
    alias CPSolver.IntVariable
    alias CPSolver.BooleanVariable
    alias CPSolver.Model

    test "equivalence: (x `relation` y) <-> b" do
      ~c"""
      MiniZinc model (for verification):
      var 0..1: x;
      var 0..1: y;

      var bool: b;

      constraint x <= y <-> b;

      Solutions:
      x = 1; y = 1; b = true;

      x = 0; y = 1; b = true;

      x = 1; y = 0; b = false;

      x = 0; y = 0; b = true;

      """

      x_domain = 0..1
      y_domain = 0..1

      for p <- [LessOrEqual, Less, Equal, NotEqual, Absolute] do
        model1 = make_model(x_domain, y_domain, p, Reified)
        {:ok, res} = CPSolver.solve_sync(model1)
        assert res.statistics.solution_count == num_sols(p, Reified)
        assert Enum.all?(res.solutions, fn s -> check_solution(s, p, Reified) end)

        ## The order of variables doesn't matter
        model2 = make_model(x_domain, y_domain, p, Reified, fn [x, y, b] -> [b, x, y] end)
        {:ok, res} = CPSolver.solve_sync(model2)
        assert res.statistics.solution_count == num_sols(p, Reified)

        assert Enum.all?(res.solutions, fn [b_value, x_value, y_value] = s ->
                 check_solution([x_value, y_value, b_value], p, Reified)
               end)
      end
    end

    test "implication (half-reification): (x `relation` y) -> b" do
      ~c"""
      Minizinc model:
      var 0..1: x;
      var 0..1: y;

      var bool: b;

      constraint x <= y -> b;
      """

      x_domain = 0..1
      y_domain = 0..1

      for p <- [LessOrEqual, Less, Equal, NotEqual, Absolute] do
        model = make_model(x_domain, y_domain, p, HalfReified)
        {:ok, res} = CPSolver.solve_sync(model)
        assert res.statistics.solution_count == num_sols(p, HalfReified)
        assert Enum.all?(res.solutions, fn s -> check_solution(s, p, HalfReified) end)
      end
    end

    test "inverse implication (inverse half-reification): (x `relation` y) <- b" do
      ~c"""
      Minizinc model:
      var 0..1: x;
      var 0..1: y;

      var bool: b;

      constraint x <= y <- b;
      """

      x_domain = 0..1
      y_domain = 0..1

      for p <- [LessOrEqual, Less, Equal, NotEqual, Absolute] do
        model = make_model(x_domain, y_domain, p, InverseHalfReified)
        {:ok, res} = CPSolver.solve_sync(model)
        assert res.statistics.solution_count == num_sols(p, InverseHalfReified)
        assert Enum.all?(res.solutions, fn s -> check_solution(s, p, InverseHalfReified) end)
      end
    end

    test "Absolute, reified (both negatives and positives in domains)" do
      x_domain = -1..1
      y_domain = -1..1
      for {mode, expected_num_sols} <- [
        {Reified, 9},
        {HalfReified, 15},
        {InverseHalfReified, 12}
      ]
        do
        model = make_model(x_domain, y_domain, Absolute, mode)
        {:ok, res} = CPSolver.solve_sync(model)
        assert Enum.all?(res.solutions, fn s -> check_solution(s, Absolute, mode) end)
        assert res.statistics.solution_count == expected_num_sols
      end
    end

    defp make_model(
           x_domain,
           y_domain,
           constraint_mod,
           reif_impl,
           order_fun \\ &Function.identity/1
         ) do
      x = IntVariable.new(x_domain, name: "x")
      y = IntVariable.new(y_domain, name: "y")
      b = BooleanVariable.new(name: "b")
      le_constraint = constraint_mod.new(x, y)
      Model.new(order_fun.([x, y, b]), [reif_impl.new(le_constraint, b)])
    end

    defp check_solution([x, y, b] = _solution, constraint_impl, reification_mod) do
      checker = Map.get(constraint_data(), constraint_impl)[:check_fun]

      case reification_mod do
        Reified -> checker.(x, y) && b == 1 || b == 0
        HalfReified -> !checker.(x, y) || b == 1
        InverseHalfReified -> checker.(x, y) || b == 0
      end
    end

    defp num_sols(constraint_impl, reification_mod) do
      get_in(constraint_data(), [constraint_impl, :num_sols, reification_mod])
    end

    defp constraint_data() do
      %{
        LessOrEqual => %{
          check_fun: fn x, y -> x <= y end,
          num_sols: %{Reified => 4, HalfReified => 5, InverseHalfReified => 7}
        },
        Less => %{
          check_fun: fn x, y -> x < y end,
          num_sols: %{Reified => 4, HalfReified => 7, InverseHalfReified => 5}
        },
        Equal => %{
          check_fun: fn x, y -> x == y end,
          num_sols: %{Reified => 4, HalfReified => 6, InverseHalfReified => 6}
        },
        NotEqual => %{
          check_fun: fn x, y -> x != y end,
          num_sols: %{Reified => 4, HalfReified => 6, InverseHalfReified => 6}
        },
        Absolute => %{
          check_fun: fn x, y -> abs(x) == y end,
          num_sols: %{Reified => 4, HalfReified => 6, InverseHalfReified => 6}
        }

      }
    end
  end
end
