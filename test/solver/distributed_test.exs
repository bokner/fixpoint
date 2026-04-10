defmodule CPSolverTest.Distributed do
  use ExUnit.Case

  test "distibuted Sudoku and Queens" do
   assert CPSolver.Distributed.test()
  end
end
