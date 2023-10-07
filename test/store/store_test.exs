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

    test "Store variables" do
      v1_values = 1..10
      v2_values = -5..5
      v3_values = [0, 3, 6, 9, -1]
      values = [v1_values, v2_values, v3_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, bound_vars, store} = ConstraintStore.create_store(variables)

      store_var_ids = ConstraintStore.get_variables(store)
      assert length(bound_vars) == store_var_ids |> length

      ## Make sure that the sets of bound vars and store vars coincide.
      assert Enum.all?(
               Enum.zip(Enum.sort(store_var_ids), Enum.sort_by(bound_vars, fn v -> v.id end)),
               fn {store_var, bound_var} ->
                 store_var == bound_var.id
               end
             )
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

      {:ok, bound_vars, store} = ConstraintStore.create_store(variables)

      [v1, v2, v3] = bound_vars
      # remove
      refute Enum.any?(bound_vars, fn var ->
               assert ConstraintStore.update(store, var, :remove, [1]) in [:domain_change, :fixed]
               ConstraintStore.get(store, var, :contains?, [1])
             end)

      assert ConstraintStore.get(store, v3, :fixed?)
      assert ConstraintStore.get(store, v3, :min) == 2

      # Remove on fixed var
      assert :fail == ConstraintStore.update(store, v3, :remove, [2])

      assert :fail == ConstraintStore.get(store, v3, :contains?, [1])
      assert :fail == ConstraintStore.update(store, v3, :remove, [2])
      assert :fail == ConstraintStore.get(store, v3, :size)

      # removeAbove
      :max_change = ConstraintStore.update(store, v1, :removeAbove, [5])
      assert ConstraintStore.get(store, v1, :max) == 5
      assert ConstraintStore.get(store, v1, :min) == 2

      # removeBelow
      :min_change = ConstraintStore.update(store, v2, :removeBelow, [0])
      assert ConstraintStore.get(store, v2, :max) == 5
      assert ConstraintStore.get(store, v2, :min) == 0

      # fix variable with value outside the domain
      assert ConstraintStore.update(store, v1, :fix, [0]) == :no_change
      assert ConstraintStore.get(store, v1, :max) == 5

      :fixed = ConstraintStore.update(store, v2, :fix, [0])
      assert ConstraintStore.get(store, v2, :max) == 0
    end

    test "Store subscriptions" do
      v1_values = -5..5
      v2_values = 1..10
      v3_values = 1..2
      values = [v1_values, v2_values, v3_values]

      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, [v1, v2, _v3] = bound_vars, store} =
        ConstraintStore.create_store(variables)

      ## No notifications, if no subscriptions
      assert :max_change == ConstraintStore.update(store, v2, :removeAbove, [5])

      refute_received _, 10

      ## Subscribe to :min_change for all variables
      ConstraintStore.subscribe(
        store,
        Enum.map(bound_vars, fn v -> %{variable: v.id, pid: self(), events: [:min_change]} end)
      )

      assert :min_change == ConstraintStore.update(store, v1, :removeBelow, [0])

      id = v1.id
      assert_received {:min_change, ^id}, 10
    end

    test "Dispose of store variables for Local" do
      v1_values = -5..5
      v2_values = 1..10
      v3_values = 1..2
      values = [v1_values, v2_values, v3_values]

      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, _bound_vars, store} =
        ConstraintStore.create_store(variables, CPSolver.Store.Local)

      ConstraintStore.dispose(store, :ignore)
      Process.sleep(10)
      refute Process.alive?(store.handle)
    end
  end
end
