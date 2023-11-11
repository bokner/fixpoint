defmodule CPSolverTest.Propagator do
  use ExUnit.Case

  describe "Propagator general" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Propagator.{NotEqual, LessOrEqual}
    alias CPSolver.ConstraintStore
    alias CPSolver.Propagator

    test "Propagator variables have :fixed flag instead of domain" do
      x = Variable.new(1..2)
      y = Variable.new(1..1)
      propagator = LessOrEqual.new([x, y])
      [p_x, p_y] = propagator.args
      refute p_x.fixed?
      assert p_y.fixed?
      refute Enum.any?(propagator.args, fn v -> Map.get(v, :domain) end)
    end

    test "filtering with variables bound to a store" do
      %{bound_variables: bound_variables, store: store} =
        setup_store([1..1, 1..2])

      [x_bound, y_bound] = bound_variables

      refute Variable.fixed?(y_bound)
      assert Variable.fixed?(x_bound)
      propagator = NotEqual.new(bound_variables)
      assert {:changed, %{y_bound.id => :fixed}} == Propagator.filter(propagator)
      assert ConstraintStore.get(store, y_bound, :fixed?)
    end

    test "filtering with variables not bound to a store" do
      %{variables: variables, bound_variables: bound_variables, store: store} =
        setup_store([1..1, 1..2])

      [x_bound, y_bound] = bound_variables
      [_x, y] = variables

      refute Variable.fixed?(y_bound)
      assert Variable.fixed?(x_bound)
      ## Variables are not bound to a store
      refute Enum.any?(variables, fn v -> Map.get(v, :store) end)
      propagator = NotEqual.new(variables)
      ## Not providing 'store' option results in exception
      assert_raise FunctionClauseError, fn -> Propagator.filter(propagator) end
      ## Supplying store will make filtering work on unbound variables
      assert {:changed, %{y.id => :fixed}} == Propagator.filter(propagator, store: store)
      assert ConstraintStore.get(store, y_bound, :fixed?)
    end

    defp setup_store(domains) do
      variables = Enum.map(domains, fn d -> Variable.new(d) end)
      {:ok, bound_variables, store} = ConstraintStore.create_store(variables)
      %{variables: variables, bound_variables: bound_variables, store: store}
    end
  end
end
