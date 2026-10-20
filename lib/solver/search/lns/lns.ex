defmodule CPSolver.Search.LNS do
  @callback init(opts :: Keyword.t()) :: map()
  @callback destroy(solution :: map(), lns_state :: any()) :: :todo
  @callback repair(solution :: map(), lns_state :: any()) :: :todo
  @callback accept(current_solution :: map(), new_solution :: map(), lns_state :: any()) :: :todo

  @doc """
    input: a feasible solution x
    2: xb = x;
    3: repeat
    4: xt = repair(destroy(x));
    5: if accept(xt , x) then
    6: x = xt ;
    7: end if
    8: if c(xt ) < c(xb) then
    9: xb = xt ;
    10: end if
    11: until stop criterion is met
    12: return xb
  """
  def run(lns_impl, opts) do
    {initial_solution, lns_state} = lns_impl.init(opts)
    implementation = Keyword.get(opts, :impl)
    stop_condition = Keyword.get(opts, :stop_condition)
    run_impl(initial_solution, implementation, stop_condition, lns_state)
  end

  defp run_impl(solution, lns_impl, stop_condition, lns_state) when is_atom(lns_impl) and is_function(stop_condition) do
    if stop_condition.(solution, lns_state) do
      {:ok, solution, lns_state}
    else
      {new_solution, new_state} =
        solution
        |> lns_impl.destroy()
        |> lns_impl.repair()

      best_solution = if lns_impl.accept(solution, new_solution, new_state) do
        ## new solution becomes the best known
        new_solution
      else
        solution
      end

      run_impl(best_solution, lns_impl, stop_condition, new_state)
    end
  end

end
