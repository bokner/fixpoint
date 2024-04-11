defmodule CPSolver.Examples.QAP do
  @doc """
  The Quadratic Assignment problem.
  Given: 
  - a set of n facilities;
  - a set of n locations;
  - for each pair of locations, a distance between them;
  - for each pair of facilities, a weight of the edge (e.g., the amount of supplies transported) between them. 

  Assign all facilities to different locations, such that 
  the sum of products d(i,j ) * w(i, j) 
    
    , where d(i,j) is a distance between locations i and j
      and w(i, j) is a weight of edge (i, j) 
      
    is minimized.

  <a href="https://en.wikipedia.org/wiki/Quadratic_assignment_problem">Wikipedia</a>.

  """
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Model
  alias CPSolver.Constraint.AllDifferent.FWC, as: AllDifferent
  alias CPSolver.Objective
  alias CPSolver.Search.VariableSelector.FirstFail
  import CPSolver.Constraint.Factory

  import CPSolver.Variable.View.Factory

  require Logger

  ## Read and compile data from instance file
  def model(data) when is_binary(data) do
    {_n, distances, weights} = parse_instance(data)
    model(distances, weights)
  end

  def model(distances, weights) do
    ## TODO: for now we are forced to use 0..n-1 for domains of assignment vars,
    ## as they will represent 0-based indices (i.e., x and y args) in element2d constraint.
    ## Not a big deal, but maybe think of supplying the index base for element2d as an option
    ##
    ## Note: we assume the distance and weight matrices are symmetrical,
    ## i.e., distances[i, j] = distances[j, i] and weights[i, j] == weights[j, i]
    ##

    n = length(distances)

    assignments =
      Enum.map(0..(n - 1), fn i -> Variable.new(0..(n - 1), name: "location_#{i}") end)

    ## Build "weighted distance" views and element2d constraints
    {weighted_distances, element2d_constraints} =
      for i <- 0..(n - 2), j <- (i + 1)..(n - 1), reduce: {[], []} do
        {weighted_distances_acc, constraints_acc} = acc ->
          weight = Enum.at(weights, i) |> Enum.at(j)

          if weight == 0 do
            acc
          else
            {z, element2d_constraint} =
              element2d(distances, Enum.at(assignments, i), Enum.at(assignments, j))

            w_distance = mul(z, weight)
            {[w_distance | weighted_distances_acc], [element2d_constraint | constraints_acc]}
          end
      end

    {total_cost, sum_constraint} = sum(weighted_distances, name: "total_cost")

    Model.new(
      assignments,
      [
        AllDifferent.new(assignments),
        sum_constraint
      ] ++ element2d_constraints,
      objective: Objective.minimize(total_cost),
      extra: %{n: n, distances: distances, weights: weights}
    )
  end

  def search(model) do
    location_var_names =
      Enum.take(model.variables, model.extra.n)
      |> Enum.reduce(
        MapSet.new(),
        fn v, acc -> MapSet.put(acc, v.name) end
      )

    {fn variables ->
       variable_choice(variables, location_var_names)
     end, :indomain_min}
  end

  def solution_handler(model) do
    fn solution ->
      Enum.at(solution, model.extra.n)
      |> inspect()
      |> Logger.warning()
      |> tap(fn _ ->
        (check_solution(
           Enum.map(solution, fn {_, val} -> val end),
           model.extra.distances,
           model.extra.weights
         ) &&
           Logger.warning("Correct")) || Logger.error("Wrong")
      end)
    end
  end

  defp variable_choice(variables, location_var_names) do
    {location_vars, rest} =
      Enum.split_with(variables, fn var -> var.name in location_var_names end)

    (Enum.empty?(location_vars) && FirstFail.select_variable(rest)) || List.first(location_vars)
  end

  def check_solution(solution, distances, weights) do
    n = length(distances)
    assignments = Enum.take(solution, n)
    ## In the solution, total cost follows assignments
    total_cost = Enum.at(solution, n)

    sum =
      for i <- 0..(n - 2), j <- (i + 1)..(n - 1), reduce: 0 do
        acc ->
          assignment_i = Enum.at(assignments, i)
          assignment_j = Enum.at(assignments, j)

          d = distances |> Enum.at(assignment_i) |> Enum.at(assignment_j)
          w = weights |> Enum.at(i) |> Enum.at(j)
          acc + d * w
      end

    total_cost == sum
  end

  def parse_instance(filename) do
    filename
    |> File.read!()
    |> String.split("\n", trim: true)
    |> then(fn [n_str | lines] ->
      n = String.to_integer(String.trim(n_str))

      weights =
        lines
        |> Enum.take(n)
        |> parse_matrix()

      distances =
        lines
        |> Enum.take(-n)
        |> parse_matrix()

      {n, distances, weights}
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
