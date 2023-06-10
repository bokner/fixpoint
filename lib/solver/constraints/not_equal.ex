defmodule CPSolver.Constraint.NotEqual do
  def post(x, y) do
    IO.puts("Posting with x = #{inspect(x)}, y = #{inspect(y)}")
  end

  def propagate(x, y) do
    IO.puts("Running propagation with x = #{inspect(x)}, y = #{inspect(y)}")
  end
end
