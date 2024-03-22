defmodule CPSolverTest.Store do
  use ExUnit.Case

  describe "Store" do
    alias CPSolver.ConstraintStore
    alias CPSolver.IntVariable, as: Variable

    test "create variables in the space" do
      v1_values = 1..10
      v2_values = -5..5
      values = [v1_values, v2_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, bound_vars, _store} = ConstraintStore.create_store(variables)
      ## Bound vars have space and ids assigned
      assert Enum.all?(bound_vars, fn var -> var end)
    end

    test "GET operations" do
      v1_values = 1..10
      v2_values = -5..5
      v3_values = 1..1
      values = [v1_values, v2_values, v3_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, bound_vars, store} = ConstraintStore.create_store(variables)
      # Min
      assert Enum.all?(Enum.zip(bound_vars, values), fn {var, vals} ->
               ConstraintStore.get(store, var, :min) == Enum.min(vals)
             end)

      # Max
      assert Enum.all?(Enum.zip(bound_vars, values), fn {var, vals} ->
               ConstraintStore.get(store, var, :max) == Enum.max(vals)
             end)

      # Size
      assert Enum.all?(Enum.zip(bound_vars, values), fn {var, vals} ->
               ConstraintStore.get(store, var, :size) == Range.size(vals)
             end)

      # Fixed?
      assert Enum.all?(Enum.zip(bound_vars, values), fn {var, vals} ->
               ConstraintStore.get(store, var, :fixed?) == (Range.size(vals) == 1)
             end)

      # Contains?
      assert Enum.all?(Enum.zip(bound_vars, values), fn {var, vals} ->
               Enum.all?(vals, fn val -> ConstraintStore.get(store, var, :contains?, [val]) end)
             end)
    end

    test "UPDATE operations" do
      v1_values = 1..10
      v2_values = -5..5
      v3_values = 1..2
      values = [v1_values, v2_values, v3_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, bound_vars, store} = ConstraintStore.create_store(variables, space: nil)

      [v1, v2, v3] = bound_vars
      # remove
      refute Enum.any?(bound_vars, fn var ->
               assert ConstraintStore.update(store, var, :remove, [1]) in [
                        :domain_change,
                        :min_change,
                        :fixed
                      ]

               ConstraintStore.get(store, var, :contains?, [1])
             end)

      assert ConstraintStore.get(store, v3, :fixed?)
      assert ConstraintStore.get(store, v3, :min) == 2

      # Remove on fixed var
      assert :fail == ConstraintStore.update(store, v3, :remove, [2])

      # removeAbove
      :max_change = ConstraintStore.update(store, v1, :removeAbove, [5])
      assert ConstraintStore.get(store, v1, :max) == 5
      assert ConstraintStore.get(store, v1, :min) == 2

      # removeBelow
      :min_change = ConstraintStore.update(store, v2, :removeBelow, [0])
      assert ConstraintStore.get(store, v2, :max) == 5
      assert ConstraintStore.get(store, v2, :min) == 0

      # fix variable with value outside the domain
      assert ConstraintStore.update(store, v1, :fix, [0]) == :fail

      :fixed = ConstraintStore.update(store, v2, :fix, [0])
      assert ConstraintStore.get(store, v2, :max) == 0
    end
  end
end
