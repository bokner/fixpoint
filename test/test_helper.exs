Logger.configure(level: :error)
ExUnit.start(capture_log: true)

alias CPSolver.Propagator
alias CPSolver.IntVariable, as: Variable
alias CPSolver.Propagator.NotEqual
alias CPSolver.Propagator.ConstraintGraph

defmodule CPSolver.Test.Helpers do
  def number_of_occurences(string, pattern) do
    string |> String.split(pattern) |> length() |> Kernel.-(1)
  end

  def create_store(variables) do
    {:ok, bound_vars, store} = CPSolver.ConstraintStore.create_store(variables)
    {:ok, Arrays.to_list(bound_vars), store}
  end

  def space_setup(x, y, z) do
    variables =
      Enum.map([{x, "x"}, {y, "y"}, {z, "z"}], fn {d, name} -> Variable.new(d, name: name) end)

    {:ok, bound_vars, store} =
      create_store(variables)

    bound_vars = [x_var, y_var, z_var] = bound_vars

    propagators =
      Enum.map(
        [{x_var, y_var, "x != y"}, {y_var, z_var, "y != z"}, {x_var, z_var, "x != z"}],
        fn {v1, v2, name} -> Propagator.new(NotEqual, [v1, v2], name: name) end
      )

    graph = ConstraintGraph.create(propagators)

    {updated_graph, _bound_propagators} = ConstraintGraph.update(graph, bound_vars)

    %{
      propagators: propagators,
      variables: bound_vars,
      constraint_graph: updated_graph,
      store: store
    }
  end
end
