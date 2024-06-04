defmodule CPSolverTest.Variable.View do
  use ExUnit.Case

  alias CPSolver.DefaultDomain, as: Domain

  describe "Views" do
    alias CPSolver.ConstraintStore
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Variable.View
    alias CPSolver.Variable.Interface
    import CPSolver.Variable.View.Factory

    test "'minus' view" do
      v1_values = 1..10
      v2_values = -5..5
      v3_values = 0..0
      v4_values = 1..1
      values = [v1_values, v2_values, v3_values, v4_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, bound_vars, _store} =
        ConstraintStore.create_store(variables)
        [source_var, var2, _var3, _var4] = Arrays.to_list(bound_vars)
      views = [view1, view2, view3, view4] = Enum.map(bound_vars, fn var -> minus(var) end)
      ## Domains of variables that back up views do not change
      assert Variable.min(source_var) == 1
      assert Variable.max(source_var) == 10
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
      assert :fail == catch_throw(View.fix(view3, 1))
    end

    test "'mul' view" do
      domain = 1..10

      {:ok, bound_vars, _store} =
        ConstraintStore.create_store([Variable.new(domain)])
      source_var = Arrays.get(bound_vars, 0)

      view1 = mul(source_var, 1)
      view2 = mul(source_var, 10)
      view3 = mul(source_var, -90)

      assert 1 == View.min(view1)
      assert 10 == View.max(view1)
      assert 10 == View.min(view2)
      assert 100 == View.max(view2)
      assert -900 == View.min(view3)
      assert -90 == View.max(view3)

      assert Variable.contains?(source_var, 1)
      assert View.contains?(view1, 1)
      refute View.contains?(view2, 1)

      assert :no_change == View.remove(view1, 100)
      assert View.domain(view2) |> Enum.sort() == Enum.map(1..10, fn val -> 10 * val end)
      assert :max_change == View.remove(view2, 100)
      ## After removing from view2, other views will be affected
      assert 9 == View.max(view1)
      assert -810 == View.min(view3)
      ## ...as will the source variable
      assert 9 == Variable.max(source_var)

      assert :min_change == View.removeAbove(view3, -450)
      assert 5 == Variable.min(source_var)
      assert 5 == View.min(view1)
      assert 50 == View.min(view2)
      assert -450 == View.max(view3)

      assert :fixed == View.fix(view2, 50)
      assert View.fixed?(view1) && View.fixed?(view3) && Variable.fixed?(source_var)
    end

    test "remove value that falls in the hole" do
      {:ok, bound_vars, _store} =
        ConstraintStore.create_store([Variable.new(0..5, name: "x")])
      x = Arrays.get(bound_vars, 0)

      y_plus = mul(x, 20)
      y_minus = mul(x, -20)

      ## View with positive coefficient
      assert 0 == View.min(y_plus)
      ## 10 is in the domain hole for the view
      assert :min_change == View.removeBelow(y_plus, 10)
      assert 20 == View.min(y_plus)
      ## 30 is in the domain hole as well
      assert :max_change == View.removeAbove(y_plus, 70)

      assert 1 == Variable.min(x)
      assert 3 == Variable.max(x)

      ## View with negative coefficient
      assert -60 == View.min(y_minus)
      assert :min_change == View.removeAbove(y_minus, -30)
      assert -40 == View.max(y_minus)
      assert :fixed == View.removeBelow(y_minus, -50)

      ## All views and the source variable are fixed
      assert Enum.all?([x, y_plus, y_minus], fn v -> Interface.fixed?(v) end)
      ## Views are fixed to the values that correspond their coefficients
      assert 2 == Interface.min(x)
      assert 2 * 20 == Interface.min(y_plus)
      assert 2 * -20 == Interface.min(y_minus)
    end
  end

  defp compare_domains(d1, d2, map_fun) do
    Enum.zip(Domain.to_list(d1) |> Enum.sort(:desc), Domain.to_list(d2) |> Enum.sort(:asc))
    |> Enum.all?(fn {val1, val2} -> val2 == map_fun.(val1) end)
  end
end
