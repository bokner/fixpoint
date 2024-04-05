defmodule CPSolverTest.Propagator do
  use ExUnit.Case

  describe "Propagator general" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Propagator.{NotEqual, LessOrEqual}
    alias CPSolver.ConstraintStore
    alias CPSolver.Propagator

    import CPSolver.Variable.View.Factory

    test ":fixed? flag for propagator variables" do
      x = Variable.new(1..2)
      y = Variable.new(1..1)
      propagator = LessOrEqual.new([x, y])
      [p_x, p_y] = propagator.args
      refute p_x.fixed?
      assert p_y.fixed?
    end

    test "filtering with variables bound to a store" do
      %{bound_variables: bound_variables, store: store} =
        setup_store([1..1, 1..2])

      [x_bound, y_bound] = bound_variables

      refute Variable.fixed?(y_bound)
      assert Variable.fixed?(x_bound)
      propagator = NotEqual.new(bound_variables)

      assert %{changes: %{y_bound.id => :fixed}, active?: true, state: nil} ==
               Propagator.filter(propagator)

      assert ConstraintStore.get(store, y_bound, :fixed?)
    end

    test "Using views" do
      x = 1..10
      y = 0..10
      variables = Enum.map([x, y], fn d -> Variable.new(d) end)

      {:ok, [x_var, y_var] = _bound_vars, _store} =
        ConstraintStore.create_store(variables, space: nil)

      ## Make 'minus' view
      minus_y_view = minus(y_var)
      ## Inconsistency: no solution to x <= -y
      ##
      ## The propagator will fail on one of the variables
      assert :fail = Propagator.filter(LessOrEqual.new(x_var, minus_y_view))
    end

    defp setup_store(domains) do
      variables = Enum.map(domains, fn d -> Variable.new(d) end)
      {:ok, bound_variables, store} = ConstraintStore.create_store(variables)
      %{variables: variables, bound_variables: bound_variables, store: store}
    end
  end
end
