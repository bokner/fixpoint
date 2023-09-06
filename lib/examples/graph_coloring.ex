defmodule CPSolver.Examples.GraphColoring do
  alias CPSolver.Constraint.NotEqual
  alias CPSolver.IntVariable

  def solve(instance, solver_opts \\ [])

  def solve(instance, solver_opts) when is_binary(instance) do
    instance
    |> parse_instance()
    |> solve(solver_opts)
  end

  def solve(data, solver_opts) do
    color_vars = Enum.map(1..data.vertices, fn _idx -> IntVariable.new(1..data.max_color) end)

    edge_color_constraints =
      Enum.map(data.edges, fn [v1, v2] ->
        {NotEqual, Enum.at(color_vars, v1), Enum.at(color_vars, v2)}
      end)

    model = %{
      variables: color_vars,
      constraints: edge_color_constraints
    }

    {:ok, _solver} =
      CPSolver.solve(model, solver_opts)
      |> tap(fn _ -> Process.sleep(100) end)
  end

  defp parse_instance(instance) do
    [header | edge_lines] = File.read!(instance) |> String.split("\n", trim: true)
    [v, _e, max_color] = header |> String.split(" ", trim: true) |> Enum.map(&String.to_integer/1)

    edges =
      Enum.map(edge_lines, fn e -> String.split(e, " ") |> Enum.map(&String.to_integer/1) end)

    %{vertices: v, edges: edges, max_color: max_color}
  end

  def check_solution(colors, instance) when is_list(colors) do
    graph = parse_instance(instance)
    Enum.all?(graph.edges, fn [v1, v2] -> Enum.at(colors, v1) != Enum.at(colors, v2) end)
  end
end
