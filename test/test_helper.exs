ExUnit.start(capture_log: true)
Logger.configure(level: :error)
ExUnited.start()

defmodule CPSolver.Test.Helpers do
  def number_of_occurences(string, pattern) do
    string |> String.split(pattern) |> length() |> Kernel.-(1)
  end
end
