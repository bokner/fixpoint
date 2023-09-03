defmodule CPSolverTest.Store do
  use ExUnit.Case

  import ExUnit.CaptureLog
  import CPSolver.Test.Helpers

  describe "Registry store" do
    alias CPSolver.Store.Registry, as: Store
    alias CPSolver.IntVariable, as: Variable

    test "create variables in the space" do
      space = self()
      v1_values = 1..10
      v2_values = -5..5
      values = [v1_values, v2_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, bound_vars} = Store.create(space, variables)
      ## Bound vars have space and ids assigned
      assert Enum.all?(bound_vars, fn var -> var && var.space == space end)
      ## Var ids point to registered variable processes
      assert Enum.all?(Enum.zip(bound_vars, values), fn {var, vals} ->
               [{pid, _}] = Registry.lookup(Store, var.id)

               Agent.get(pid, fn state -> CPSolver.DefaultDomain.min(state) end) ==
                 Enum.min(vals)
             end)
    end

    test "Space variables" do
      space = self()
      v1_values = 1..10
      v2_values = -5..5
      v3_values = [0, 3, 6, 9, -1]
      values = [v1_values, v2_values, v3_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, bound_vars} = Store.create(space, variables)

      store_var_ids = Store.get_variables(space)
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
      space = self()
      v1_values = 1..10
      v2_values = -5..5
      v3_values = 1..1
      values = [v1_values, v2_values, v3_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, bound_vars} = Store.create(space, variables)
      # Min
      assert Enum.all?(Enum.zip(bound_vars, values), fn {var, vals} ->
               Store.get(space, var, :min) == Enum.min(vals)
             end)

      # Max
      assert Enum.all?(Enum.zip(bound_vars, values), fn {var, vals} ->
               Store.get(space, var, :max) == Enum.max(vals)
             end)

      # Size
      assert Enum.all?(Enum.zip(bound_vars, values), fn {var, vals} ->
               Store.get(space, var, :size) == Range.size(vals)
             end)

      # Fixed?
      assert Enum.all?(Enum.zip(bound_vars, values), fn {var, vals} ->
               Store.get(space, var, :fixed?) == (Range.size(vals) == 1)
             end)

      # Contains?
      assert Enum.all?(Enum.zip(bound_vars, values), fn {var, vals} ->
               Enum.all?(vals, fn val -> Store.get(space, var, :contains?, [val]) end)
             end)
    end

    test "UPDATE operations" do
      space = self()
      v1_values = 1..10
      v2_values = -5..5
      v3_values = 1..2
      values = [v1_values, v2_values, v3_values]
      variables = Enum.map(values, fn d -> Variable.new(d) end)

      {:ok, bound_vars} = Store.create(space, variables)

      [v1, v2, v3] = bound_vars
      # remove
      refute Enum.any?(bound_vars, fn var ->
               assert Store.update(space, var, :remove, [1]) in [:domain_change, :fixed]
               Store.get(space, var, :contains?, [1])
             end)

      assert Store.get(space, v3, :fixed?)
      assert Store.get(space, v3, :min) == 2

      # Remove on fixed var
      assert :fail = Store.update(space, v3, :remove, [2])

      assert :fail == Store.get(space, v3, :contains?, [1])
      assert :fail == Store.update(space, v3, :remove, [2])
      assert :fail == Store.get(space, v3, :size)

      # removeAbove
      :max_change = Store.update(space, v1, :removeAbove, [5])
      assert Store.get(space, v1, :max) == 5
      assert Store.get(space, v1, :min) == 2

      # removeBelow
      :min_change = Store.update(space, v2, :removeBelow, [0])
      assert Store.get(space, v2, :max) == 5
      assert Store.get(space, v2, :min) == 0

      # fix variable with value outside the domain
      :fail = Store.update(space, v1, :fix, [0])
      assert Store.get(space, v1, :max) == :fail

      :fixed = Store.update(space, v2, :fix, [0])
      assert Store.get(space, v2, :max) == 0
    end

    test "no_change events are not fired more than once in a row" do
      space = self()
      v1_values = 1..10
      v2_values = -5..5
      values = [v1_values, v2_values]
      [v1, v2] = Enum.map(values, fn d -> Variable.new(d) end)
      {:ok, _bound_vars} = Store.create(space, [v1, v2])

      log =
        capture_log([level: :debug], fn ->
          Enum.each(1..10, fn _ -> Store.update(space, v1, :removeAbove, [5]) end)
          Process.sleep(10)
        end)

      matching_str = "No change for variable #{inspect(v1.id)}"
      # assert log =~ matching_str
      assert number_of_occurences(log, matching_str) == 1
    end
  end
end
