defmodule CPSolverTest.Propagator.Element2D do
  use ExUnit.Case

  describe "Propagator filtering" do
    alias CPSolver.ConstraintStore
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Variable.Interface
    alias CPSolver.Propagator
    alias CPSolver.Propagator.Element2D

    test "filtering" do
      x = -2..40
      y = -3..10
      z = 2..40

      t = [
        [9, 8, 7, 5, 6],
        [9, 1, 5, 2, 8],
        [8, 3, 1, 4, 9],
        [9, 1, 2, 8, 6]
      ]

      variables = Enum.map([x, y, z], fn d -> Variable.new(d) end)

      {:ok,  bound_vars, _store} = ConstraintStore.create_store(variables)
      [x_var, y_var, z_var] = Arrays.to_list(bound_vars)

      propagator = Element2D.new(t, x_var, y_var, z_var)

      %{state: state1} = Propagator.filter(propagator)

      assert Interface.min(x_var) == 0
      assert Interface.max(x_var) == 3
      assert Interface.min(y_var) == 0
      assert Interface.max(y_var) == 4
      assert Interface.min(z_var) == 2
      assert Interface.max(z_var) == 9

      Interface.removeAbove(z_var, 7)

      %{state: state2} = Propagator.filter(Map.put(propagator, :state, state1))

      assert Interface.min(y_var) == 1

      Interface.remove(x_var, 0)
      %{state: state3} = Propagator.filter(Map.put(propagator, :state, state2))

      assert 6 == Interface.max(z_var)
      assert 3 == Interface.max(x_var)

      Interface.remove(y_var, 4)

      %{state: state4} = Propagator.filter(Map.put(propagator, :state, state3))

      assert 5 == Interface.max(z_var)
      assert 2 == Interface.min(z_var)

      %{state: state5} = Propagator.filter(Map.put(propagator, :state, state4))

      Interface.remove(y_var, 2)
      %{state: _state6} = Propagator.filter(Map.put(propagator, :state, state5))

      assert 4 == Interface.max(z_var)
      assert 2 == Interface.min(z_var)
    end

    test "inconsistency" do
      x = 1..2
      y = -10..1
      z = -2..6

      t = [
        [3, 5],
        [7, 8]
      ]

      variables = Enum.map([x, y, z], fn d -> Variable.new(d) end)

      {:ok, bound_vars, _store} = ConstraintStore.create_store(variables)
      [x_var, y_var, z_var] = Arrays.to_list(bound_vars)
      ## The propagator will fail.
      ## D(x) = 1..2 implies filtering to {1} (because T is 2x2, and it's a 0-based index)
      ## This leaves only the second row for the values of z, which is inconsistent with D(z).
      propagator = Element2D.new(t, x_var, y_var, z_var)
      assert :fail == Propagator.filter(propagator)
    end

    test "2 of 3 fixed" do
      x = 3..3
      y = 3..3
      z = 2..40

      t = [
        [9, 8, 7, 5, 6],
        [9, 1, 5, 2, 8],
        [8, 3, 1, 4, 9],
        [9, 1, 2, 8, 6]
      ]

      variables = Enum.map([x, y, z], fn d -> Variable.new(d) end)

      {:ok,  bound_vars, _store} = ConstraintStore.create_store(variables)
      [x_var, y_var, z_var] = Arrays.to_list(bound_vars)

      propagator = Element2D.new(t, x_var, y_var, z_var)

      %{state: nil, active?: false} = Propagator.filter(propagator)

      assert Interface.min(z_var) ==
               Enum.at(t, Interface.min(x_var)) |> Enum.at(Interface.min(y_var))

      assert Interface.fixed?(z_var)
    end
  end
end
