defmodule CpSolverTest do
  use ExUnit.Case

  alias CPSolver.IntVariable
  alias CPSolver.Model
  alias CPSolver.Constraint.NotEqual
  alias CPSolver.Examples.Queens
  alias CPSolver.Examples.Knapsack

  @solution_handler_test_file "solution_handler_test.tmp"

  setup do
    File.touch(@solution_handler_test_file)
    on_exit(fn -> File.rm(@solution_handler_test_file) end)
    :ok
  end

  test "Solves CSP with 2 variables and a single constraint" do
    x = IntVariable.new([1, 2])
    y = IntVariable.new([0, 1])

    model =
      Model.new(
        [x, y],
        [NotEqual.new(x, y)]
      )

    {:ok, solver} = CPSolver.solve(model)

    Process.sleep(100)

    assert CPSolver.statistics(solver).failure_count == 0
    ## Note: there are 2 "first fail" distributions:
    ## 1. Variable 'x' triggers distribution into 2 spaces - (x: 1, y: [0, 1]) and (x: 2, y: [0, 1])).
    ## 2. First space produces solution (x: 1, y: 0)
    ## 3. Second space triggers distribution into 2 spaces - (x: 2, y: 0) and (x: 2, y: 1)
    ## 4. These 2 spaces produce remaining solutions.
    ## 5. There have been 5 spaces - top one, and 4 as described above, which corresponds
    ## to 5 nodes.
    assert CPSolver.statistics(solver).node_count == 5
    assert CPSolver.statistics(solver).solution_count == 3

    solutions =
      solver
      |> CPSolver.solutions()
      |> Enum.sort_by(fn [x, y] -> x + y end)

    assert solutions == [[1, 0], [2, 0], [2, 1]]
  end

  test "Stops on max_solutions reached" do
    max_solutions = 2
    {:ok, solver} = Queens.solve(5, stop_on: {:max_solutions, max_solutions})
    Process.sleep(100)
    assert CPSolver.complete?(solver)
  end

  test "Synchronous solver" do
    {:ok, result} = CPSolver.solve_sync(Queens.model(8))
    assert result.statistics.solution_count == 92
    ## No active nodes - solving is done
    assert result.statistics.active_node_count == 0
  end

  test "Solver status" do
    ## N-Queens for n = 3 is unatisfiable
    {:ok, res} = CPSolver.solve_sync(Queens.model(3))
    assert res.status == :unsatisfiable
    ## N-Queens for n = 4
    {:ok, res} = CPSolver.solve_sync(Queens.model(4))
    assert res.status == :all_solutions
    ## N-Queens for n = 8, async solving
    {:ok, solver} = CPSolver.solve(Queens.model(8))
    Process.sleep(10)
    {:running, _} = CPSolver.status(solver)
    Process.sleep(100)
    assert :all_solutions = CPSolver.status(solver)
    ## Status for optimization problem
    {:ok, solver} = CPSolver.solve(Knapsack.model("data/knapsack/ks_4_0"))
    Process.sleep(100)
    assert {:optimal, [objective: 19]} == CPSolver.status(solver)
  end

  test "Solution handler" do
    x = IntVariable.new([1, 2])
    y = IntVariable.new([0, 1])

    model =
      Model.new(
        [x, y],
        [NotEqual.new(x, y)]
      )

    {:ok, res} =
      CPSolver.solve_sync(model,
        solution_handler: fn solution ->
          File.write!(@solution_handler_test_file, :erlang.term_to_binary(solution) <> "\n", [
            :append
          ])
        end
      )

    solutions_from_file =
      @solution_handler_test_file
      |> File.read!()
      |> String.trim()
      |> String.split("\n")
      |> Enum.map(fn binary -> :erlang.binary_to_term(binary) end)

    ## Make {ref, value} list off the solver solutions
    ## to be able to compare with the output of solutuon handler
    solver_solutions =
      Enum.map(res.solutions, fn sol -> Enum.zip(res.variables, sol) end)
      |> List.flatten()
      |> Enum.sort()

    handler_solutions = List.flatten(solutions_from_file) |> Enum.sort()
    assert solver_solutions == handler_solutions
  end
end
