defmodule CPSolverTest.Propagator.Modulo do
  use ExUnit.Case
  import CPSolver.Test.Helpers

  describe "Propagator filtering" do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.DefaultDomain, as: Domain
    alias CPSolver.Variable.Interface
    alias CPSolver.Propagator
    alias CPSolver.Propagator.Modulo

    test "filtering, initial call" do
      ## Both vars are unfixed
      x = 1..10
      y = -5..5
      m = -10..10
      variables = Enum.map([m, x, y], fn d -> Variable.new(d) end)

      {:ok, [m_var, _x_var, y_var] = bound_vars, _store} = create_store(variables)
      # before filtering
      assert Interface.contains?(y_var, 0)
      assert Interface.min(m_var) == -10

      p = Modulo.new(bound_vars)
      _res = Propagator.filter(p)
      ## y has 0 removed
      refute Interface.contains?(y_var, 0)

      ## Nothing is fixed
      refute Enum.any?(bound_vars, fn var -> Interface.fixed?(var) end)
    end

    test "filtering, dividend and divisor fixed" do
      x = -7
      y = 3
      m = -10..10
      variables = Enum.map([m, x, y], fn d -> Variable.new(d) end)

      {:ok, [m_var, _x_var, _y_var] = bound_vars, _store} = create_store(variables)
      p = Modulo.new(bound_vars)
      res = Propagator.filter(p)

      assert res.changes == %{m_var.id => :fixed}

      ## Modulo is fixed to x % y
      ## Dividend and modulo have the same sign
      assert Interface.fixed?(m_var) && Interface.min(m_var) == rem(x, y)
    end

    test "filtering, modulo and dividend fixed" do
      x = -10
      y = -100..100
      m = -2
      variables = Enum.map([m, x, y], fn d -> Variable.new(d) end)

      {:ok, [_m_var, _x_var, y_var] = bound_vars, _store} = create_store(variables)
      p = Modulo.new(bound_vars)
      res = Propagator.filter(p)
      refute res == :fail
      ## All values in domain of y satisfy x % y = m
      assert Enum.all?(Domain.to_list(y_var.domain), fn y_val ->
               rem(x, y_val) == m
             end)
    end

    test "filtering, modulo and divider fixed" do
      x = -100..100
      y = -10
      m = -2
      variables = Enum.map([m, x, y], fn d -> Variable.new(d) end)

      {:ok, [_m_var, x_var, _y_var] = bound_vars, _store} = create_store(variables)
      p = Modulo.new(bound_vars)
      res = Propagator.filter(p)
      refute res == :fail
      ## All values in domain of x satisfy x % y = m
      assert Enum.all?(Domain.to_list(x_var.domain), fn x_val -> rem(x_val, y) == m end)
    end

    test "inconsistency, if modulo and dividend are fixed to values of different sign" do
      x = 10
      y = -100..100
      m = -2
      variables = Enum.map([m, x, y], fn d -> Variable.new(d) end)

      {:ok, bound_vars, _store} = create_store(variables)
      p = Modulo.new(bound_vars)

      assert :fail = Propagator.filter(p)
    end

    test "inconsistency, if every modulo value has a different sign with every divident value" do
      m = 1..10
      y = -100..100
      x = -10..-1
      variables = Enum.map([m, x, y], fn d -> Variable.new(d) end)

      {:ok, bound_vars, _store} = create_store(variables)
      p = Modulo.new(bound_vars)

      assert :fail = Propagator.filter(p)
    end

  end
end
