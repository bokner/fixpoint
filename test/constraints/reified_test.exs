defmodule CPSolverTest.Constraint.Reified do
  use ExUnit.Case, async: false

  describe "Reification" do
    alias CPSolver.Constraint.{Reified, HalfReified, InverseHalfReified}
    alias CPSolver.Constraint.{Equal, NotEqual, LessOrEqual, Less}
    alias CPSolver.IntVariable
    alias CPSolver.BooleanVariable
    alias CPSolver.Model

    test "equivalence: x<=y <-> b" do
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

      for p <- [LessOrEqual, Less, Equal, NotEqual] do
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

    test "implication (half-reification): x<=y -> b" do
      ~c"""
      Minizinc model:
      var 0..1: x;
      var 0..1: y;

      var bool: b;

      constraint x <= y -> b;
      """

      x_domain = 0..1
      y_domain = 0..1

      for p <- [LessOrEqual, Less, Equal, NotEqual] do
        model = make_model(x_domain, y_domain, p, HalfReified)
        {:ok, res} = CPSolver.solve_sync(model)
        assert res.statistics.solution_count == num_sols(p, HalfReified)
        assert Enum.all?(res.solutions, fn s -> check_solution(s, p, HalfReified) end)
      end
    end

    test "inverse implication (inverse half-reification): x<=y <- b" do
      ~c"""
      Minizinc model:
      var 0..1: x;
      var 0..1: y;

      var bool: b;

      constraint x <= y <- b;
      """

      x_domain = 0..1
      y_domain = 0..1

      for p <- [LessOrEqual, Less, Equal, NotEqual] do
        model = make_model(x_domain, y_domain, p, InverseHalfReified)
        {:ok, res} = CPSolver.solve_sync(model)
        assert res.statistics.solution_count == num_sols(p, InverseHalfReified)
        assert Enum.all?(res.solutions, fn s -> check_solution(s, p, InverseHalfReified) end)
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
        Reified -> b == 0 || (checker.(x, y) && b == 1)
        HalfReified -> b == 1 || !checker.(x, y)
        InverseHalfReified -> b == 0 || checker.(x, y)
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
        }
      }
    end
  end
end
