defmodule CPSolver.Propagator.Reified do
  use CPSolver.Propagator

  alias CPSolver.BooleanVariable, as: BoolVar
  alias CPSolver.Propagator


  @moduledoc """
  The propagator for reification constraints.

  Full reification:

   1. if b_var is fixed to 1, filter on all propagators;
   2. if b_var is fixed to 0, filter on all "opposite" propagators (stop if any of these propagators is resolved);
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
  def filter([propagators, b_var, mode], %{opposite: opposite_propagators} = state, changes) do
    cond do
      mode == :full && BoolVar.true?(b_var) ->
        propagate_direct(propagators, changes)

      BoolVar.false?(b_var) ->
        propagate_opposite(propagators, changes)

        resolved?(propagators) ->
        BoolVar.set_true(b_var)
        :passive

      mode == :full && resolved?(opposite_propagators) ->
        BoolVar.set_false(b_var)
        :passive

      true -> {:state, state}
    end
  end

  defp initial_state([propagators, _b_var, _mode]) do
    %{opposite: opposite_propagators(propagators)}
  end

  defp propagate_direct(propagators, incoming_changes) do
    :todo
  end

  defp propagate_opposite(propagators, incoming_changes) do
    :todo
  end

  defp resolved?(propagators) do
    Enum.all?(propagators, fn p ->
      Propagator.entailed?(p)
    end)
  end

  defp opposite_propagators(propagators) do
    Enum.filter(propagators, fn p -> opposite(p) end)
  end



  ## Opposite propagators
  alias CPSolver.Propagator.{Equal, NotEqual, Less, LessOrEqual}

  defp opposite(%{mod: Equal} = p) do
    %{p | mod: NotEqual}
  end

  defp opposite(%{mod: NotEqual} = p) do
    %{p | mod: Equal}
  end

  defp opposite(%{mod: mod} = p) when mod in [Less, LessOrEqual] do
    swap_args(p)
  end

  defp swap_args(%{args: [x, y | rest]} = p) do
    %{p | args: [y, x | rest]}
  end

end
