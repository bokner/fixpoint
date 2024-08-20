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

  Inverse implication:

  Rules 1 and 4 of full reification.
  """
  def new(propagators, b_var, mode) when mode in [:full, :half] do
    new([propagators, b_var, mode])
  end

  @impl true
  def variables([propagators, b_var, _mode]) do
    Enum.reduce(
      propagators,
      [set_propagate_on(b_var, :fixed)],
      fn p, acc -> acc ++ Propagator.variables(p) end
    )
    |> Enum.uniq()
  end

  @impl true
  def reset([propagators, b_var, _mode] = args, state, opts) do
    state && state || %{active_propagators: bind_variables(propagators, Keyword.get(opts, :constraint_graph))}
  end

  @impl true
  def filter(args) do
    filter(args, initial_state(args), %{})
  end

  @impl true
  def filter(args, nil, changes) do
    filter(args, initial_state(args), changes)
  end

  def filter(
        [propagators, b_var, mode] = args,
        %{active_propagators: active_propagators} = _state,
        changes
      ) do
        #Propagator.get_store_from_dict()
        IO.inspect(b_var.store, label: :store)
        IO.inspect(variables(args) |> Enum.map(fn var -> {var.name, Domain.to_list(domain(var))} end), label: :variables)
        filter_impl(mode, b_var, active_propagators, changes)
  end

  defp actions() do
    %{:full => [
      &propagate/2,
      &propagate_negative/2,
      &terminate_false/1,
      &terminate_true/1],
      :half => [nil, &propagate_negative/2, nil, &terminate_true/1],
      :inverse => [&propagate/2, nil, &terminate_false/1, nil]

    }
  end

  defp bind_variables(propagators, constraint_graph) do
    IO.inspect(constraint_graph, label: :constraint_graph)
    propagators
    |> Enum.map(fn p -> p end)
  end

  ## Callbacks for reified
  defp propagate(propagators, incoming_changes) do
    res = Enum.reduce_while(propagators, [], fn p, active_propagators_acc ->
      IO.inspect(p.mod, label: :propagate)
      case Propagator.filter(p, changes: incoming_changes) do
        :fail -> {:halt, :fail}
        %{active?: active?} ->
          {:cont, active? && [p | active_propagators_acc] || active_propagators_acc}
      end
    end)

    cond do
      res == :fail -> :fail
      #Enum.empty?(res) -> :passive
      true -> {:state, %{active_propagators: res}}
    end
  end

  defp propagate_negative(propagators, changes) do
    propagators
    |> opposite_propagators()
    |> propagate(changes)
  end


  defp terminate_true(b_var) do
    terminate_propagator(b_var, true)
  end

  defp terminate_false(b_var) do
    terminate_propagator(b_var, false)
  end

  defp terminate_propagator(b_var, bool) do
    bool && BoolVar.set_true(b_var) || BoolVar.set_false(b_var)
    :passive
  end


  defp filter_impl(mode, b_var, propagators, changes) do
    #IO.inspect({self(), Enum.map(propagators, fn p -> Propagator.propagator_domain_values(p) end)}, label: :propagator_values)
    [propagate_action, propagate_negative_action, fix_to_false_action, fix_to_true_action] = Map.get(actions(), mode)
    cond do
      BoolVar.true?(b_var) ->
        IO.inspect(label: :b_true)
        (propagate_action && propagate_action.(propagators, changes) && active_state(propagators) || :passive)
      BoolVar.false?(b_var) ->
        IO.inspect(label: :b_false)
        (propagate_negative_action && propagate_negative_action.(propagators, changes) && active_state(propagators) || :passive)
      true ->
        IO.inspect(label: :b_not_fixed)
        ## Control variable is not fixed
        case check_propagators(propagators, changes) do
          :fail -> fix_to_false_action && fix_to_false_action.(b_var) || :passive
          :resolved -> fix_to_true_action && fix_to_true_action.(b_var) || :passive
          {:active, active_propagators} ->
            active_state(active_propagators)
        end
        end
  end

  defp initial_state([propagators, _b_var, _mode]) do
    %{active_propagators: propagators}
  end

  defp check_propagators(propagators, incoming_changes) do
    propagators
    |> Enum.reduce_while([],
      fn p, active_propagators_acc ->
        case Propagator.filter(p, changes: incoming_changes, dry_run: true) |> IO.inspect(label: :check) do
          :fail -> {:halt, :fail}
          %{active?: active?} ->
            {:cont, active? && [p | active_propagators_acc] || active_propagators_acc}
        end
      end)
      |> case do
        :fail -> :fail
        active_propagators ->
          Enum.empty?(active_propagators) && :resolved || {:active, active_propagators}
        end

  end


  defp opposite_propagators(propagators) do
    Enum.map(propagators, fn p -> opposite(p) end)
  end

  ## Opposite propagators
  alias CPSolver.Propagator.{Equal, NotEqual, Less, LessOrEqual}

  defp opposite(%{mod: Equal} = p) do
    %{p | mod: NotEqual}
  end

  defp opposite(%{mod: NotEqual} = p) do
    %{p | mod: Equal}
  end

  defp opposite(%{mod: Less} = p) do
    %{p | mod: LessOrEqual}
    |> swap_args()
  end

  defp opposite(%{mod: LessOrEqual} = p) do
    %{p | mod: Less}
    |> swap_args()
  end

  defp active_state(propagators) do
    {:state, %{active_propagators: propagators}}
  end

  defp swap_args(%{args: [x, y | rest]} = p) do
    %{p | args: [y, x | rest]}
  end
end
