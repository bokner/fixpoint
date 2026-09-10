defmodule CPSolver.Search.LNS do
  @callback init(model :: map()) :: :todo
  @callback destroy(solution :: map()) :: :todo
  @callback repair(solution :: map()) :: :todo
  @callback accept(current_solution :: map(), new_solution :: map()) :: :todo

  @doc """
    input: a feasible solution x
    2: xb = x;
    3: repeat
    4: xt = r(d(x));
    5: if accept(xt , x) then
    6: x = xt ;
    7: end if
    8: if c(xt ) < c(xb) then
    9: xb = xt ;
    10: end if
    11: until stop criterion is met
    12: return xb
  """
  def run(opts) do
    initial_solution = Keyword.get(opts, :initial_solution)
    implementation = Keyword.get(opts, :impl)
    stop_condition = Keyword.get(opts, :stop_condition)
  end


end
