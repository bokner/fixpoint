defmodule CPSolver.Propagator.Reified do
  use CPSolver.Propagator


  @moduledoc """
  The propagator for reification constraints.

  Full reification:

   1. if b_var is fixed to 1, filter on all propagators;
   2. if b_var is fixed to 0, filter on all "opposite" propagators (stop if any propagator is resolved);
   3. if all propagators are resolved (i.e., entailed or passive), fix b to 1;
   4. if any propagator fails, fix b to 0.

  Half-reification:

  Rules 2 and 3 of full reification.
  """
  def new(propagators, b_var, mode) when mode in [:full, :half] do
    new([propagators, b_var, mode])
  end

  @impl true
  def variables([propagators, b_var, _mode]) do
    Enum.reduce(propagators,
    [set_propagate_on(b_var, :fixed)],
    fn p, acc -> acc ++ Propagator.variables(p)
    end) |> Enum.uniq()
  end

  @impl true
  def filter(args) do
    filter(args, initial_state(args))
  end

  @impl true
  def filter([_propagators, _b_var, _mode], _state, _changes) do
    {:state, %{}}
  end

  defp initial_state(_args) do
    %{}
  end


end
