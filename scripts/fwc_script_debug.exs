defmodule FWCDebug do
  # alias CPSolver.ConstraintStore
  alias CPSolver.IntVariable, as: Variable
  # alias CPSolver.Variable.Interface
  # alias CPSolver.Propagator
  alias CPSolver.Constraint
  # alias CPSolver.Propagator.AllDifferent.FWC
  alias CPSolver.Constraint.AllDifferent.FWC, as: FWC_Constraint
  alias CPSolver.Model
  import CPSolver.Variable.View.Factory

  # {:ok, x_vars, _store} = ConstraintStore.create_store(x)

  ## Initial state
  ##
  # row_propagator = FWC.new(x_vars)

  # indexed_q = Enum.with_index(x_vars, 1)

  # diagonal_down = Enum.map(indexed_q, fn {var, idx} -> linear(var, 1, -idx) end)
  # diagonal_down_propagator = FWC.new(diagonal_down)

  # diagonal_up = Enum.map(indexed_q, fn {var, idx} -> linear(var, 1, idx) end)
  # diagonal_up_propagator = FWC.new(diagonal_up)

  # propagators = [row_propagator, diagonal_down_propagator, diagonal_up_propagator]
  # order = Enum.shuffle(1..3)

  # filtering_results =
  # Enum.map(order, fn i -> Enum.at(propagators, i-1) end) |> Enum.map(fn p -> Propagator.filter(p) end)

  # Enum.map(x_vars, fn v -> Interface.domain(v) end)
  def debug(x) do
    row_constraint = Constraint.new(FWC_Constraint, x)
    indexed_x = Enum.with_index(x, 1)
    diagonal_down_views = Enum.map(indexed_x, fn {var, idx} -> linear(var, 1, idx) end)
    diagonal_down_constraint = Constraint.new(FWC_Constraint, diagonal_down_views)
    diagonal_up_views = Enum.map(indexed_x, fn {var, idx} -> linear(var, 1, -idx) end)

    diagonal_up_constraint = Constraint.new(FWC_Constraint, diagonal_up_views)

    order = Enum.shuffle(1..3)
    constraint_names = [:row, :down, :up]

    all_constraints = [row_constraint, diagonal_down_constraint, diagonal_up_constraint]

    model =
      Model.new(
        x,
        Enum.map(order, fn ord -> Enum.at(all_constraints, ord - 1) end)
      )

    {:ok, res} = CPSolver.solve(model)
    res |> Map.put(:order, Enum.zip(order, constraint_names))
  end

  def trace(x, patterns) do
    Replbug.start(patterns,
      time: :timer.seconds(10),
      msgs: 100_000,
      max_queue: 100_000,
      silent: true
    )

    Process.sleep(50)
    res = debug(x)
    Process.sleep(100)
    traces = Replbug.stop()
    res.status != :unsatisfiable && %{result: res, traces: traces}
  end

  def trace(x, patterns, n) do
    Enum.reduce_while(1..n, nil, fn _, _acc ->
      res = trace(x, patterns)
      (res && {:halt, res}) || {:cont, nil}
    end)
  end
end

"""
x =
Enum.map(
  [
    {"row1", 5},
    {"row2", 1},
    {"row3", [4]},
    {"row4", [4, 6]},
    {"row5", [2, 3, 6]},
    {"row6", [2, 3, 4, 6]}
  ],
  fn {name, d} ->
    Variable.new(d, name: name)
  end
)

patterns = ["CPSolver.Propagator.filter/_"]

FWCDebug.trace(x, patterns, 100)
"""

######################
## Propagation
######################
"""
alias CPSolver.Propagator.AllDifferent.FWC
alias CPSolver.Variable.Interface
import CPSolver.Variable.View.Factory

variables =
  Enum.map(
    [
      {"row1", 5},
      {"row2", 1},
      {"row3", 4},
      {"row4", [4, 6]},
      {"row5", [2, 3, 6]},
      {"row6", [2, 3, 4, 6]}
    ],
    fn {name, d} ->
      Variable.new(d, name: name)
    end
  )

{:ok, x_vars, store} =
  ConstraintStore.create_store(variables)

row_propagator = Propagator.new(FWC, x_vars, name: "row")

indexed_q = Enum.with_index(x_vars, 1)

diagonal_down = Enum.map(indexed_q, fn {var, idx} -> linear(var, 1, idx) end)
diagonal_down_propagator = Propagator.new(FWC, diagonal_down, name: "down")

diagonal_up = Enum.map(indexed_q, fn {var, idx} -> linear(var, 1, -idx) end)
diagonal_up_propagator = Propagator.new(FWC, diagonal_up, name: "up")

propagators = [row_propagator, diagonal_up_propagator, diagonal_down_propagator]
graph = ConstraintGraph.create(propagators)

## 3 propagators and 6 variables
assert Graph.num_vertices(graph) == 9

{scheduled_propagators, reduced_graph} = Propagation.propagate(propagators, graph, store)
assert MapSet.size(scheduled_propagators) == 1
assert MapSet.member?(scheduled_propagators, row_propagator.id)

assert ConstraintGraph.get_propagator(reduced_graph, row_propagator.id)
    |> get_in([:state, :unfixed_vars]) == %{}

assert Enum.all?(x_vars, fn var -> Interface.fixed?(var) end)
assert Graph.num_vertices(reduced_graph) == 6
"""
