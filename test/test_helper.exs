Logger.configure(level: :error)
ExUnit.start(capture_log: true, exclude: [:superslow])

alias CPSolver.Propagator
alias CPSolver.IntVariable, as: Variable
alias CPSolver.Propagator.NotEqual
alias CPSolver.Propagator.ConstraintGraph
alias Iter.Iterable

defmodule CPSolver.Test.Helpers do
  def number_of_occurences(string, pattern) do
    string |> String.split(pattern) |> length() |> Kernel.-(1)
  end

  def space_setup(x, y, z) do
    variables =
      Enum.map([{x, "x"}, {y, "y"}, {z, "z"}], fn {d, name} -> Variable.new(d, name: name) end)

    [x_var, y_var, z_var] = variables

    propagators =
      Enum.map(
        [{x_var, y_var, "x != y"}, {y_var, z_var, "y != z"}, {x_var, z_var, "x != z"}],
        fn {v1, v2, name} -> Propagator.new(NotEqual, [v1, v2], name: name) end
      )

    graph = ConstraintGraph.create(propagators)

    updated_graph = ConstraintGraph.update(graph, variables)

    %{
      propagators: propagators,
      variables: variables,
      constraint_graph: updated_graph
    }
  end

  ## Compare two iterables
  def iterables_equal?(iterable1, iterable2) do
    Iterable.to_list(iterable1) |> Enum.sort()
    == Iterable.to_list(iterable2) |> Enum.sort()
  end
end
