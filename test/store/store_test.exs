defmodule CPSolverTest.Store do
  use ExUnit.Case, async: false

  describe "Registry store" do
    alias CPSolver.Store.Registry, as: Store
    alias CPSolver.IntVariable, as: Variable

    test "create variables in the space" do
      space = :top_space
      v1_values = 1..10
      v2_values = -5..5
      values = [v1_values, v2_values]
      {:ok, bound_vars} = Store.create(space, Enum.map(values, fn d -> Variable.new(d) end))
      ## Bound vars have space and ids assigned
      assert Enum.all?(bound_vars, fn var -> var.id && var.space == space end)
      ## Var ids point to registered variable processes
      assert Enum.all?(Enum.zip(bound_vars, values), fn {var, vals} ->
               [{pid, _}] = Registry.lookup(Store, var.id)

               Agent.get(pid, fn state -> CPSolver.DefaultDomain.min(state) end) ==
                 Enum.min(vals)
             end)
    end

    test "Space variables" do
      space = :top_space
      v1_values = 1..10
      v2_values = -5..5
      v3_values = [0, 3, 6, 9, -1]
      values = [v1_values, v2_values, v3_values]
      {:ok, bound_vars} = Store.create(space, Enum.map(values, fn d -> Variable.new(d) end))

      store_vars = Store.get_variables(space)
      assert length(bound_vars) == store_vars |> length

      ## Make sure that the sets of bound vars and store vars coincide.
      assert Enum.all?(
               Enum.zip(Enum.sort(store_vars), Enum.sort_by(bound_vars, fn v -> v.id end)),
               fn {store_var, bound_var} ->
                 store_var == bound_var.id
               end
             )
    end

    test "GET operations" do
      space = :top_space
      v1_values = 1..10
      v2_values = -5..5
      v3_values = 1..1
      values = [v1_values, v2_values, v3_values]
      {:ok, bound_vars} = Store.create(space, Enum.map(values, fn d -> Variable.new(d) end))
      # Min
      assert Enum.all?(Enum.zip(bound_vars, values), fn {var, vals} ->
               Store.get(space, var.id, :min) == Enum.min(vals)
             end)

      # Max
      assert Enum.all?(Enum.zip(bound_vars, values), fn {var, vals} ->
               Store.get(space, var.id, :max) == Enum.max(vals)
             end)

      # Size
      assert Enum.all?(Enum.zip(bound_vars, values), fn {var, vals} ->
               Store.get(space, var.id, :size) == Range.size(vals)
             end)

      # Fixed?
      assert Enum.all?(Enum.zip(bound_vars, values), fn {var, vals} ->
               Store.get(space, var.id, :fixed?) == (Range.size(vals) == 1)
             end)

      # Contains?
      assert Enum.all?(Enum.zip(bound_vars, values), fn {var, vals} ->
               Enum.all?(vals, fn val -> Store.get(space, var.id, :contains?, [val]) end)
             end)
    end

    test "UPDATE operations" do
      space = :top_space
      v1_values = 1..10
      v2_values = -5..5
      v3_values = 1..2
      values = [v1_values, v2_values, v3_values]
      {:ok, bound_vars} = Store.create(space, Enum.map(values, fn d -> Variable.new(d) end))

      [v1, v2, v3] = bound_vars
      # remove
      refute Enum.any?(bound_vars, fn var ->
               :ok = Store.update(space, var.id, :remove, [1])
               Store.get(space, var.id, :contains?, [1])
             end)

      assert Store.get(space, v3.id, :fixed?)
      assert Store.get(space, v3.id, :min) == 2

      # Remove on fixed var
      :ok = Store.update(space, v3.id, :remove, [2])

      assert :fail == Store.get(space, v3.id, :contains?, [1])
      assert :ok == Store.update(space, v3.id, :remove, [2])
      assert :fail == Store.get(space, v3.id, :size)

      # removeAbove
      :ok = Store.update(space, v1.id, :removeAbove, [5])
      assert Store.get(space, v1.id, :max) == 5
      assert Store.get(space, v1.id, :min) == 2

      # removeBelow
      :ok = Store.update(space, v2.id, :removeBelow, [0])
      assert Store.get(space, v2.id, :max) == 5
      assert Store.get(space, v2.id, :min) == 0

      # fix
      :ok = Store.update(space, v1.id, :fix, [0])
      assert Store.get(space, v1.id, :max) == :fail

      :ok = Store.update(space, v2.id, :fix, [0])
      assert Store.get(space, v2.id, :max) == 0
    end
  end
end
