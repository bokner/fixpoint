defmodule CPSolverTest.Propagator do
  use ExUnit.Case

  describe "Propagator general" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Variable.Interface
    alias CPSolver.Propagator.{NotEqual, LessOrEqual}
    alias CPSolver.Propagator
  
    import CPSolver.Variable.View.Factory

    test "filtering with variables bound to a store" do
      %{variables: variables} =
        setup_store([1..1, 1..2])

      [x_var, y_var] = variables

      refute Variable.fixed?(y_var)
      assert Variable.fixed?(x_var)
      propagator = NotEqual.new(variables)

      assert %{changes: %{y_var.id => :fixed}, active?: false, state: nil} ==
               Propagator.filter(propagator)

      assert Interface.fixed?(y_var)
    end

    test "Using views" do
      x = 1..10
      y = 0..10
      variables = Enum.map([x, y], fn d -> Variable.new(d) end)

      [x_var, y_var] = variables

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
      %{variables: variables} =
        setup_store([1..1, 1..2])

      [x_var, y_var] = variables

      assert Variable.fixed?(x_var)
      refute Variable.fixed?(y_var)

      propagator = NotEqual.new(variables)

      ## Dry-run first
      {_p_copy, dry_run_result} = Propagator.dry_run(propagator)
      assert dry_run_result == %{changes: %{y_var.id => :fixed}, active?: false, state: nil}

      # Store variables didn't change
      assert Variable.fixed?(x_var)
      refute Variable.fixed?(y_var)

      ## Real run now
      real_run_result = Propagator.filter(propagator)
      ## The results of dry run vs. real run
      assert dry_run_result == real_run_result

      ## Variables are fixed, as expected
      assert Variable.fixed?(x_var)
      assert Variable.fixed?(y_var)
    end

    test "dry run (inconsistency, view)" do
      x = 1..10
      y = 0..10
      variables = Enum.map([x, y], fn d -> Variable.new(d) end)

      [x_var, y_var] = variables

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
      %{variables: variables}
    end
  end
end
