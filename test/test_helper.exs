ExUnit.start(capture_log: true)
Logger.configure(level: :error)

Registry.start_link(
  name: CPSolver.Store.Registry,
  keys: :unique,
  partitions: System.schedulers_online()
)

defmodule CPSolver.Test.Helpers do
  def number_of_occurences(string, pattern) do
    string |> String.split(pattern) |> length() |> Kernel.-(1)
  end
end
