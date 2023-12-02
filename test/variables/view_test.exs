defmodule CPSolverTest.Variable.View do
  use ExUnit.Case

  alias CPSolver.DefaultDomain, as: Domain

  describe "Views" do
    alias CPSolver.ConstraintStore
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Variable.View
    import CPSolver.Variable.View.Factory

    test "'minus' view" do
      v1_values = 1..10
      v2_values = -5..5
      v3_values = 0..0
      v4_values = 1..1
      values = [v1_values, v2_values, v3_values, v4_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, [var1, var2, _var3, _var4] = bound_vars, _store} =
        ConstraintStore.create_store(variables)

      views = [view1, view2, view3, view4] = Enum.map(bound_vars, fn var -> minus(var) end)
      ## Domains of variables that back up views do not change
      assert Variable.min(var1) == 1
      assert Variable.max(var1) == 10
      ## :min and :max
      assert View.min(view1) == -10
      assert View.max(view1) == -1
      assert View.min(view2) == -5
      assert View.max(view2) == 5
      assert View.min(view3) == 0 && View.max(view3) == 0
      assert View.min(view4) == -1 && View.max(view4) == -1

      ## Size
      assert Enum.all?(Enum.zip(bound_vars, views), fn {var, view} ->
               Variable.size(var) == View.size(view)
             end)

      ## Fixed?
      refute View.fixed?(view1) || View.fixed?(view2)
      assert View.fixed?(view3) && View.fixed?(view4)

      ## Domain
      assert Enum.all?(Enum.zip(bound_vars, views), fn {var, view} ->
               compare_domains(View.domain(view), Variable.domain(var), fn x -> -x end)
             end)

      ## :contains?
      refute Enum.any?(v1_values, fn v -> View.contains?(view1, v) end)
      assert Enum.all?(v1_values, fn v -> View.contains?(view1, -v) end)

      ## Remove
      assert View.contains?(view1, -5)
      assert :domain_change == View.remove(view1, -5)
      refute View.contains?(view1, -5)
      assert :no_change == View.remove(view1, 1)

      ## Remove above
      assert :no_change == View.removeAbove(view1, 4)
      ## removeAbove/removeBelow report domain changes for source variables,
      ## not for views, hence :min_change for removeAbove
      assert :min_change == View.removeAbove(view1, -4)
      assert -4 == View.max(view1)
      assert -10 == View.min(view1)

      ## Remove below
      assert Domain.to_list(View.domain(view1)) == [-10, -9, -8, -7, -6, -4]
      ## Same as for removeAbove, :max_change reflects the domain change for the variable,
      ## and not the view.
      assert :max_change == View.removeBelow(view1, -7)
      assert Domain.to_list(View.domain(view1)) == [-7, -6, -4]
      assert :fixed == View.removeBelow(view1, -4)
      assert -4 == View.min(view1)

      ## Fix
      assert :fixed == View.fix(view2, -1)
      assert View.fixed?(view2) && Variable.fixed?(var2)
      assert View.min(view2) == -1 && Variable.min(var2) == 1
      assert :fail == View.fix(view3, 1)
    end
  end

  defp compare_domains(d1, d2, map_fun) do
    Enum.zip(Domain.to_list(d1) |> Enum.sort(:desc), Domain.to_list(d2) |> Enum.sort(:asc))
    |> Enum.all?(fn {val1, val2} -> val2 == map_fun.(val1) end)
  end
end
