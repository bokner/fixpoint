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
  alias CPSolver.Objective
  import CPSolver.Constraint.Factory

  ## Read and compile data from instance file
  def model(data) when is_binary(data) do
    {_n, distances} = parse_instance(data)
    model(distances)
  end

  def model(distances) do
    n = length(distances)

    ## successor[i] = j <=> location j follows location i  
    successors =
      Enum.map(0..(n - 1), fn i -> Variable.new(0..(n - 1), name: "succ_#{i}") end)

    ## Distance between location i and the one that follows i (i.e., successor)   
    #  dist_succ = Enum.map(0..n - 1, fn i -> Variable.new(Enum.at(distance, i), name: "dist_succ#{i}")

    #  end)

    ## Element constrains
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
        sum_constraint
      ] ++ element_constraints,
      objective: Objective.minimize(total_distance),
      extra: %{n: n, distances: distances}
    )
  end

  def check_solution(solution, distances) do
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
end
