defmodule Propagation do
  alias CPSolver.ConstraintStore
  alias CPSolver.IntVariable
  alias CPSolver.Variable
  alias CPSolver.Propagator
  alias CPSolver.Propagator.NotEqual

  def setup() do
    x = 1..1
    y = -5..5
    z = 0..0
    variables = Enum.map([{x, "x"}, {y, "y"}, {z, "z"}], fn {d, name} -> IntVariable.new(d, name: name) end)

    {:ok, [x_var, y_var, z_var] = bound_vars, store} =
      ConstraintStore.create_store(variables)

    Enum.each(bound_vars, fn v -> IO.puts("#{inspect v.id} -> #{inspect v.name}") end)
    propagators = Enum.map([{x_var, y_var}, {y_var, z_var}, {x_var, z_var}],
      fn {v1, v2} -> NotEqual.new([v1, v2]) end)
    %{propagators: propagators, variables: variables, store: store}
  end

  def propagate(propagators, variables, store) do
    Enum.reduce_while(propagators, %{}, fn p, acc ->
      case Propagator.filter(p) do
        {:changed, change} -> {:cont, Map.merge(acc, change)}
        :stable -> {:cont, acc}
        {:fail, _var} -> {:halt, :fail}
      end

    end)
  end

  def run() do
    %{propagators: propagators, variables: variables, store: store} = setup()
    propagate(propagators, variables, store)
  end
end
