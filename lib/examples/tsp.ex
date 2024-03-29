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
  alias CPSolver.Constraint.{Circuit, Less}
  alias CPSolver.Objective
  alias CPSolver.Variable.Interface
  alias CPSolver.DefaultDomain, as: Domain
  alias CPSolver.Search.VariableSelector.FirstFail
  import CPSolver.Constraint.Factory

  require Logger

  ## Read and compile data from instance file
  def model(data) when is_binary(data) do
    {_n, distances} = parse_instance(data)
    model(distances)
  end

  def model(distances) do
    n = length(distances)

    ## successor[i] = j <=> location j follows location i  
    successors =
      Enum.map(0..(n - 1), fn i ->
        Variable.new(0..(n - 1), name: "succ_#{i}")
      end)

    # ++ [Variable.new(0, name: "succ_#{n - 1}")]

    ## Element constraints
    ## For each i, distance between i and it's successor must be in i-row of distance matrix
    {dist_succ, element_constraints} =
      Enum.map(0..(n - 1), fn i ->
        element(Enum.at(distances, i), Enum.at(successors, i))
      end)
      |> Enum.unzip()

    {total_distance, sum_constraint} = sum(dist_succ, name: "total_distance")

    Model.new(
      successors ++ [total_distance],
      [
        Circuit.new(successors),
        Less.new(Enum.at(successors, 0), Enum.at(successors, 1)),
        sum_constraint
      ] ++ element_constraints,
      objective: Objective.minimize(total_distance),
      extra: %{n: n, distances: distances}
    )
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

    total_distance == sum_distances && n == MapSet.new(successors) |> MapSet.size()
  end

  def search(%{extra: %{distances: distances, n: n}} = _model) do
    choose_value_fun = fn %{index: idx} = var ->
      domain = Interface.domain(var)
      d_values = Domain.to_list(domain)

      (idx in 1..n &&
         Enum.min_by(d_values, fn dom_idx -> Enum.at(distances, idx - 1) |> Enum.at(dom_idx) end)) ||
        Enum.random(d_values)
    end

    choose_variable_fun = fn variables ->
      {circuit_vars, rest_vars} = Enum.split_with(variables, fn v -> v.index <= n end)

      (circuit_vars == [] && FirstFail.select_variable(rest_vars)) ||
        difference_between_closest_distances(circuit_vars, distances)
    end

    {choose_variable_fun, choose_value_fun}
    # {:input_order, choose_value_fun}
  end

  def solution_handler(model) do
    fn solution -> Enum.at(solution, model.extra.n) |> inspect() |> Logger.warning() end
  end

  ## Choose the variable with the maximum difference between closest and second closest distance to its successors
  ## 
  defp difference_between_closest_distances(circuit_vars, distances) do
    Enum.max_by(circuit_vars, fn %{index: idx} = var ->
      dom = Interface.domain(var) |> Domain.to_list()

      (length(dom) < 2 && 0) ||
        dom
        |> Enum.map(fn value ->
          Enum.at(distances, idx - 1) |> Enum.at(value)
        end)
        |> Enum.sort(:desc)
        |> then(fn dists -> abs(Enum.at(dists, 1) - hd(dists)) end)
    end)
  end

  # end

  ## solution -> sequence of visits 
  def to_route(solution, %{extra: %{n: n}} = _model) do
    circuit = Enum.take(solution, n)

    Enum.reduce(0..(n - 1), [0], fn _idx, [next | _rest] = acc ->
      [Enum.at(circuit, next) | acc]
    end)
    |> Enum.reverse()
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
