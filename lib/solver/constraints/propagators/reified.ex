defmodule CPSolver.Propagator.Reified do
  use CPSolver.Propagator

  alias CPSolver.BooleanVariable, as: BoolVar
  alias CPSolver.Propagator

  @moduledoc """
  The propagator for reification constraints.

  Full reification:

   1. If b is fixed to 1, the propagator for the reification reduces to a propagator for C.
   2. If b is fixed to 0, the propagator for the reification reduces to a propagator for opposite(C).
   3. If a propagator for C would realize that the C would be entailed, the propagator for the reification fixes b to 1 and ceases to exist.
   4. If a propagator for C would realize that the C would fail, the propagator for the reification fixes x b to 0 and ceases to exist.

   Half-reification:

  Rules 2 and 3 of full reification.

  Inverse implication:

  Rules 1 and 4 of full reification.
  """
  def new(propagators, b_var, mode) when mode in [:full, :half, :inverse_half] do
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
  def filter(args) do
    filter(args, initial_state(args), %{})
  end

  @impl true
  def filter(args, nil, changes) do
    filter(args, initial_state(args), changes)
  end

  def filter(
        [_propagators, b_var, mode] = _args,
        %{active_propagators: active_propagators} = _state,
        changes
      ) do
    filter_impl(mode, b_var, active_propagators, changes)
  end

  @impl true
  def bind(%{args: [propagators, b_var, mode] = _args} = propagator, source, var_field) do
    bound_propagators = Enum.map(propagators, fn p -> Propagator.bind(p, source, var_field) end)
    Map.put(propagator, :args, [bound_propagators, Propagator.bind_to_variable(b_var, source, var_field), mode])
    |> Map.put(:state, %{active_propagators: bound_propagators})
  end

  defp actions() do
    %{
      :full => [
        &propagate/2,
        &propagate_negative/2,
        &terminate_false/1,
        &terminate_true/1
      ],
      :half => [nil, &propagate_negative/2, nil, &terminate_true/1],
      :inverse_half => [&propagate/2, nil, &terminate_false/1, nil]
    }
  end

  ## Callbacks for reified
  defp propagate(propagators, incoming_changes) do
    res =
      Enum.reduce_while(propagators, [], fn p, active_propagators_acc ->
        case Propagator.filter(p, changes: incoming_changes) do
          :fail ->
            {:halt, :fail}

          %{active?: active?} ->
            {:cont, (active? && [p | active_propagators_acc]) || active_propagators_acc}

          :stable ->
            {:cont, [p | active_propagators_acc]}
        end
      end)

    cond do
      res == :fail -> :fail
      Enum.empty?(res) -> :passive
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
    (bool && fix(b_var, 1)) || fix(b_var, 0)
    :passive
  end

  defp filter_impl(mode, b_var, propagators, changes) do
    [propagate_action, propagate_negative_action, fix_to_false_action, fix_to_true_action] =
      Map.get(actions(), mode)

    cond do
      BoolVar.true?(b_var) ->
        propagate_action && propagate_action.(propagators, changes) && active_state(propagators)

      BoolVar.false?(b_var) ->
        propagate_negative_action && propagate_negative_action.(propagators, changes) &&
          active_state(propagators)

      true ->
        ## Control variable is not fixed
        case check_propagators(propagators, changes) do
          :fail ->
            fix_to_false_action && fix_to_false_action.(b_var) && active_state(propagators)

          :entailed ->
            fix_to_true_action && fix_to_true_action.(b_var) && active_state(propagators)

          active_propagators ->
            active_state(active_propagators)
        end
    end
  end

  defp initial_state([propagators, _b_var, _mode]) do
    %{active_propagators: propagators}
  end

  defp check_propagators(propagators, _incoming_changes) do
    propagators
    |> Enum.reduce_while(
      [],
      fn p, active_propagators_acc ->
        cond do
          Propagator.failed?(p) ->
            {:halt, :fail}

          Propagator.entailed?(p) ->
            {:cont, active_propagators_acc}

          true ->
            {:cont, [p | active_propagators_acc]}
        end
      end
    )
    |> case do
      :fail ->
        :fail

      active_propagators ->
        (Enum.empty?(active_propagators) && :entailed) || active_propagators
    end
  end

  defp opposite_propagators(propagators) do
    Enum.map(propagators, fn p -> opposite(p) end)
  end

  ## Opposite propagators
  alias CPSolver.Propagator.{Equal, NotEqual, Less, LessOrEqual, Absolute, AbsoluteNotEqual}

  defp opposite(%{mod: Equal} = p) do
    %{p | mod: NotEqual}
  end

  defp opposite(%{mod: NotEqual} = p) do
    %{p | mod: Equal}
  end

  defp opposite(%{mod: LessOrEqual, args: [x, y, offset]} = p) do
    %{p | mod: Less, args: [y, x, -offset]}
  end

  defp opposite(%{mod: Absolute} = p) do
      %{p | mod: AbsoluteNotEqual}
  end

  defp active_state(propagators) do
    {:state, %{active?: true, active_propagators: propagators}}
  end

end
