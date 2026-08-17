defmodule CPSolver.Search.LNS do
  @callback init(model :: map()) :: :todo
  @callback destroy(model :: map(), solution :: map()) :: :todo

  def run(opts) do
    initial_solution = Keyword.get(opts, :initial_solution)
    implementation = Keyword.get(opts, :impl)
    stop_condition = Keyword.get(opts, :stop_condition)
  end


end
