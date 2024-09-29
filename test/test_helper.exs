Logger.configure(level: :error)
ExUnit.start(capture_log: true)

defmodule CPSolver.Test.Helpers do
  def number_of_occurences(string, pattern) do
    string |> String.split(pattern) |> length() |> Kernel.-(1)
  end

  def create_store(variables) do
    {:ok, bound_vars, store} = CPSolver.ConstraintStore.create_store(variables)
    {:ok, Arrays.to_list(bound_vars), store}
  end
end
