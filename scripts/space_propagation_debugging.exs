defmodule PropagationDebug do
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Propagator.NotEqual
  alias CPSolver.ConstraintStore
  alias CPSolver.Propagator
  alias CPSolver.Space.Propagation
  alias CPSolver.Propagator.ConstraintGraph

  def setup() do
    Replbug.start(
      ["CPSolver.Propagator.filter/_",
        "CPSolver.Space.Propagation.reschedule/_"],
        time: :timer.minutes(10), msgs: 100)
  end

  def run() do
    x = 1..1
    y = 1..2
    z = 1..3
    %{propagators: propagators, constraint_graph: graph, store: store} = space_setup(x, y, z)
    {_scheduled_propagators, _reduced_graph} = Propagation.propagate(propagators, graph, store)
  end

  def analyze() do
    traces = Replbug.stop
    calls = Replbug.calls(traces) |> Map.values |> List.flatten |> Enum.sort_by(fn c-> c.call_timestamp end, Time)
    Enum.map(calls, fn c ->
      {c.call_timestamp, c.function,
        c.function == :reschedule && {Enum.at(c.args, 1), c.return |> Enum.map(fn {_p_id, p} -> p.name end)}
        || {hd(c.args).name, c.return}} end)
  end

  defp space_setup(x, y, z) do
    variables =
      Enum.map([{x, "x"}, {y, "y"}, {z, "z"}], fn {d, name} -> Variable.new(d, name: name) end)

    {:ok, [x_var, y_var, z_var] = bound_vars, store} =
      ConstraintStore.create_store(variables)

    propagators =
      Enum.map(
        [{x_var, z_var, "x != z"}, {x_var, y_var, "x != y"}, {y_var, z_var, "y != z"} ],
        fn {v1, v2, name} -> Propagator.new(NotEqual, [v1, v2], name: name) end
      )
      |> Enum.reverse()

    graph = ConstraintGraph.create(propagators)

    %{
      propagators: propagators,
      variables: bound_vars,
      constraint_graph: ConstraintGraph.remove_fixed(graph, bound_vars),
      store: store
    }
  end

end
