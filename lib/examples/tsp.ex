defmodule CPSolver.Examples.TSP do
  @doc """
  The Traveling Salesman problem.
  Given:
  - a set of n locations;
  - for each pair of locations, a distance between them.

  Find the shortest possible route that visits each location exactly once and returns to the origin location.

  <a href="https://en.wikipedia.org/wiki/Travelling_salesman_problem">Wikipedia</a>.

  """
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Model
  alias CPSolver.Constraint.Circuit
  alias CPSolver.Constraint.{Equal, Less, Channel, Reified}
  alias CPSolver.Objective
  import CPSolver.Constraint.Factory
  import CPSolver.Utils
  alias CPSolver.Utils.TupleArray

  alias CPSolver.Variable.UnfixedTracker, as: Tracker

  require Logger

  @checkmark_symbol "\u2713"
  @failure_symbol "\u1D350"

  def run(instance, opts \\ []) do
    model = model(instance, opts)

    opts =
      Keyword.merge(
        [
          search: search(model),
          solution_handler: solution_handler(model),
          timeout: :timer.minutes(5),
        ],
        opts
      )

    Logger.warning("Bounds: #{model.extra.lb}, #{model.extra.ub}")
    {:ok, _res} = CPSolver.solve(model, opts)
  end

  ## Read and compile data from instance file
  def model(data, opts \\ [])
  def model(data, opts) when is_binary(data) do
    {_n, distances} = parse_instance(data)
    model(distances, opts)
  end

  def model(distances, opts) do
    n = length(distances)

    symmetry_breaking = Keyword.get(opts, :symmetry_breaking, true)
    {lb, ub} = get_bounds(distances)
    ## successor[i] = j <=> location j follows location i
    successors =
      Enum.map(0..(n - 1), fn i ->
        Variable.new(0..(n - 1), name: "succ_#{i}")
      end)

    indicators =
      for i <- 0..(n - 1) do
        for j <- 0..(n - 1) do
          if i != j do
            Variable.new(0..1)
          else
            Variable.new(0)
          end
      end
    end

    distance_vars =
      for i <- 0..(n - 1) do
        dists = Enum.at(distances, i)
        inds = Enum.at(indicators, i)
        for j <- 0..(n - 1) do
          if i != j do
            CPSolver.Variable.View.Factory.mul(Enum.at(inds, j), Enum.at(dists, j))
          else
            Variable.new(0)
          end
      end
    end


    ## Channel constraints
    channel_constraints = for i <- 0..(n - 1) do
      succ_i = Enum.at(successors, i)
      indicators = Enum.at(indicators, i)
        ## succ[i] = j iff ind[i, j] = 1
      Channel.new(CPSolver.Variable.View.Factory.inc(succ_i, 1), indicators)
    end


    ## Element constraints
    ## For each i, distance between i and it's successor must be in i-row of distance matrix
    {dist_succ, element_constraints} =
      Enum.map(0..(n - 1), fn i ->
        element(Enum.at(distances, i), Enum.at(successors, i))
      end)
      |> Enum.unzip()

    {total_distance, sum_constraint} = sum(List.flatten(distance_vars))
    ## Apply bounds
    Variable.removeBelow(total_distance, lb)
    Variable.removeAbove(total_distance, ub)

    Model.new(
      successors,
      [
        Circuit.new(successors),
        sum_constraint
      ] #++ element_constraints
      ++ channel_constraints
      ++ (symmetry_breaking && symmetry_constraints(successors) || []),

      objective: Objective.minimize(total_distance),
      extra: %{n: n, distances: distances, lb: lb, ub: ub}
    )
  end

  defp symmetry_constraints(successors) do
    zero_succ = hd(successors)
    Enum.map(1..length(successors) - 1, fn idx ->
      succ_var = Enum.at(successors, idx)
      %{constraints: constraints} = imp(Equal.new(succ_var, 0), Less.new(zero_succ, idx))
      constraints
    end
    )
  end

  defp get_bounds(distances) do
    l = length(distances)
    graph =
    Enum.reduce(1..l-1, BitGraph.new(), fn v1, acc ->
      Enum.reduce((v1 + 1)..l, acc, fn v2, acc2 ->
      BitGraph.add_edge(acc2, v1, v2)
    end)
    end)
    dist_fun = fn from, to -> Enum.at(distances, to - 1) |> Enum.at(from - 1) end
    {_edges, lb} = BitGraph.mst(graph, dist_fun: dist_fun)
    {lb, 2 * lb}
  end

  def check_solution(solution, %{extra: %{distances: distances}} = _model) do
    n = length(distances)
    successors = Enum.take(solution, n)
    ## In the solution, total cost follows assignments
    total_distance = Enum.at(solution, n)

    sum_distances =
      successors
      |> Enum.with_index()
      |> Enum.reduce(0, fn {succ, idx}, acc ->
        acc + (Enum.at(distances, idx) |> Enum.at(succ))
      end)

    hamiltonian?(successors) &&
      total_distance == sum_distances && n == MapSet.new(successors) |> MapSet.size()
  end

  def search(%{extra: %{distances: distances, n: n}} = _model) do
    tuple_matrix = TupleArray.new(distances)

    choose_value_fun = fn %{index: idx} = var ->
      d_values = domain_values(var)

      (idx in 1..n &&
         Enum.min_by(d_values, fn dom_idx -> TupleArray.at(tuple_matrix, [idx - 1, dom_idx]) end)) ||
        Enum.random(d_values)
    end

    choose_variable_fun = fn %{
      unfixed_variables_tracker: tracker,
      variables: variables} = _space_data  ->
      circuit_vars = Tracker.iterate(tracker, variables, [], fn v, acc ->
        if v.index <= n do
          [v | acc]
        else
          acc
        end
      end, false)

      if !Enum.empty?(circuit_vars) do
        difference_between_closest_distances(circuit_vars, tuple_matrix)
      end
    end

    {choose_variable_fun, choose_value_fun}
  end

  def solution_handler(model) do
    fn solution ->
      solution
      |> Enum.at(model.extra.n)
      |> tap(fn {_ref, total} ->
        ans_str = inspect({"total", total})

        (check_solution(
           Enum.map(solution, fn {_, val} -> val end),
           model
         ) &&
           Logger.warning("#{@checkmark_symbol} #{ans_str}")) ||
          Logger.error("#{@failure_symbol} #{ans_str}" <> ": wrong -((")
      end)
    end
  end

  ## Choose the variable with the maximum difference between closest and second closest distance to its successors
  ##
  defp difference_between_closest_distances(circuit_vars, distances) do
    Enum.max_by(circuit_vars, fn %{index: idx} = var ->
      dom = domain_values(var)

      (MapSet.size(dom) < 2 && 0) ||
        dom
        |> Enum.map(fn value ->
          TupleArray.at(distances, [idx - 1, value])
        end)
        |> Enum.sort(:desc)
        |> then(fn dists -> abs(Enum.at(dists, 1) - hd(dists)) end)
    end)
  end

  ## solution -> sequence of visits
  def to_route(solution, %{extra: %{n: n}} = _model) do
    circuit = Enum.take(solution, n)

    Enum.reduce(0..(n - 1), [0], fn _idx, [next | _rest] = acc ->
      [Enum.at(circuit, next) | acc]
    end)
    |> Enum.reverse()
  end

  def hamiltonian?(sequence) do
    {cycle_length, _current} =
      Enum.reduce_while(sequence, {1, 0}, fn _succ, {length_acc, succ_acc} = acc ->
        next = Enum.at(sequence, succ_acc)

        if next == 0 do
          {:halt, acc}
        else
          {:cont, {length_acc + 1, next}}
        end
      end)

    cycle_length == length(sequence)
  end

  def parse_instance(filename) do
    filename
    |> File.read!()
    |> String.split("\n", trim: true)
    |> then(fn [n_str | lines] ->
      n = String.to_integer(String.trim(n_str))

      distances =
        lines
        |> Enum.take(n)
        |> parse_matrix()

      {n, distances}
    end)
  end

  defp parse_matrix(lines) do
    Enum.map(lines, fn line ->
      line
      |> String.replace("\t", " ")
      |> String.split(" ", trim: true)
      |> Enum.map(fn num_str -> String.to_integer(String.trim(num_str)) end)
    end)
  end

  def to_dot(distances) do
    n = length(distances)

    graph =
      for i <- 0..(n - 1), j <- 0..(n - 1), reduce: Graph.new() do
        acc ->
          weight = Enum.at(distances, i) |> Enum.at(j)
          Graph.add_edge(acc, i, j, weight: weight, label: weight)
      end

    Graph.to_dot(graph)
  end
end
