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
    
    , where d(i,j) is a distance between localtions i and j
      and w(i, j) is a weight of edge (i, j) 
      
    is minimized.

  <a href="https://en.wikipedia.org/wiki/Quadratic_assignment_problem">Wikipedia</a>.

  """
  alias CPSolver.IntVariable, as: Variable
  alias CPSolver.Model
  alias CPSolver.Constraint.AllDifferent.FWC, as: AllDifferent
  alias CPSolver.Constraint.Sum
  #alias CPSolver.Constraint.Element2D
  import CPSolver.Constraint.Factory

  import CPSolver.Variable.View.Factory

  ## Read and compile data from instance file
  def model(data) when is_binary(data) do
    {n, distances, weights} = parse_instance(data)
    model(n, distances, weights)
  end

  def model(n, distances, weights) do
    ## TODO: for now we are forced to use 0..n-1 for domains of assignment vars,
    ## as they will represent 0-based indices (i.e., x and y args) in element2d constraint.
    ## Not a big deal, but maybe think of supplying the index base for element2d as an option
    ##
    assignments = Enum.map(0..n-1, fn i -> Variable.new(0..n-1, name: "location_#{i}") end)
    ## build "weighted distance" views and element2d constraints
    {weighted_distances, element2d_constrains} = 
    for i <- 0..n-1, j <- 0..n-1, reduce: {[], []} do
      {weighted_distances_acc, constraints_acc} = _acc -> 
      {z, element2d} = element2d(distances, assignments[i], assignments[j])
      w_distance = mul(z, Enum.at(weights, i) |> Enum.at(j))
      {[w_distance | weighted_distances_acc], [element2d | constraints_acc]}
    end

    Model.new(
      assignments,
      [AllDifferent.new(assignments)]
    )
  end

  defp parse_instance(filename) do
    filename
    |> File.read!()
    |> String.split("\n", trim: true)
    |> then(fn [n_str | lines] ->
      n = String.to_integer(n_str)

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
      |> String.split(" ", trim: true)
      |> Enum.map(fn num_str -> String.to_integer(num_str) end)
    end)
  end
end
