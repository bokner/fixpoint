defmodule CPSolver.BooleanVariable do
  alias CPSolver.IntVariable
  alias CPSolver.Variable.Interface

  def new() do
    IntVariable.new(0..1)
  end

  def set_false(var) do
    Interface.fix(var, 0)
  end

  def set_true(var) do
    Interface.fix(var, 1)
  end

  def true?(var) do
    fixed?(var, 1)
  end

  def false?(var) do
    fixed?(var, 0)
  end

  def fixed?(var, val) do
    Interface.fixed?(var) && Interface.min(var) == val
  end
end
