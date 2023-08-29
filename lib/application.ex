defmodule CPSolver.Application do
  def start(:normal, []) do
    Registry.start_link(
      name: CPSolver.Store.Registry,
      keys: :unique,
      partitions: System.schedulers_online()
    )
  end
end
