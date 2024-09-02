defmodule CPSolverTest.Propagator do
  use ExUnit.Case

  describe "Propagator general" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Variable.Interface
    alias CPSolver.Propagator.{NotEqual, LessOrEqual}
    alias CPSolver.ConstraintStore
    alias CPSolver.Propagator
    import CPSolver.Test.Helpers

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

      assert %{changes: %{y_bound.id => :fixed}, active?: false, state: nil} ==
               Propagator.filter(propagator)

      assert ConstraintStore.get(store, y_bound, :fixed?)
    end

    test "Using views" do
      x = 1..10
      y = 0..10
      variables = Enum.map([x, y], fn d -> Variable.new(d) end)

      {:ok, bound_vars, _store} =
        create_store(variables)

      [x_var, y_var] = bound_vars

      ## Make 'minus' view
      minus_y_view = minus(y_var)
      ## Inconsistency: no solution to x <= -y
      ##
      ## The propagator will fail on one of the variables
      assert :fail = Propagator.filter(LessOrEqual.new(x_var, minus_y_view))
    end

    test "dry run (reduction)" do
      # `dry_run` option tests the result of the propagator filtering,
      # but does not change space variables
      %{bound_variables: bound_variables} =
        setup_store([1..1, 1..2])

      [x_bound, y_bound] = bound_variables

      assert Variable.fixed?(x_bound)
      refute Variable.fixed?(y_bound)

      propagator = NotEqual.new(bound_variables)

      ## Dry-run first
      {_p_copy, dry_run_result} = Propagator.dry_run(propagator)
      assert dry_run_result == %{changes: %{y_bound.id => :fixed}, active?: false, state: nil}

      # Store variables didn't change
      assert Variable.fixed?(x_bound)
      refute Variable.fixed?(y_bound)

      ## Real run now
      real_run_result = Propagator.filter(propagator)
      ## The results of dry run vs. real run
      assert dry_run_result == real_run_result

      ## Variables are fixed, as expected
      assert Variable.fixed?(x_bound)
      assert Variable.fixed?(y_bound)
    end

    test "dry run (inconsistency, view)" do
      x = 1..10
      y = 0..10
      variables = Enum.map([x, y], fn d -> Variable.new(d) end)

      {:ok, bound_vars, _store} =
        create_store(variables)

      [x_var, y_var] = bound_vars

      minus_y_view = minus(y_var)
      {_p_copy, res} = Propagator.dry_run(LessOrEqual.new(x_var, minus_y_view))

      ## Should fail, because `minus` view turns `y` domain to -10..0
      assert res == :fail
      ## ...but the domains of variables stay intact
      assert 10 == Interface.size(x_var) && (11 = Interface.size(y_var))

      ## Now, filter for real
      assert :fail == Propagator.filter(LessOrEqual.new(x_var, minus_y_view))
      ## At least one variable is now in :fail state
      assert catch_throw(10 == Interface.size(x_var) && (11 = Interface.size(y_var))) == :fail
    end

    defp setup_store(domains) do
      variables = Enum.map(domains, fn d -> Variable.new(d) end)
      {:ok, bound_variables, store} = create_store(variables)
      %{variables: variables, bound_variables: bound_variables, store: store}
    end
  end
end
