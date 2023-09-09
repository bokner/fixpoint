defmodule CPSolver.Examples.Queens do
  alias CPSolver.Constraint.NotEqual
  alias CPSolver.IntVariable

  def solve(n, solver_opts \\ []) when is_integer(n) do
    range = 1..n
    ## Queen positions
    q = Enum.map(range, fn _ -> IntVariable.new(range) end)

    constraints =
      for i <- 0..(n - 2) do
        for j <- (i + 1)..(n - 1) do
          # queens q[i] and q[i] not on ...
          [
            ## ... the same line
            {NotEqual, Enum.at(q, i), Enum.at(q, j), 0},
            ## ... the same left diagonal
            {NotEqual, Enum.at(q, i), Enum.at(q, j), i - j},
            ## ... the same right diagonal
            {NotEqual, Enum.at(q, i), Enum.at(q, j), j - i}
          ]
        end
      end
      |> List.flatten()

    model = %{
      variables: q,
      constraints: constraints
    }

    {:ok, _solver} =
      CPSolver.solve(model, solver_opts)
      |> tap(fn _ -> Process.sleep(100) end)
  end
end
