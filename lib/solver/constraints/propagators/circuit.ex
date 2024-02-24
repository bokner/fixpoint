defmodule CPSolver.Propagator.Circuit do
  use CPSolver.Propagator

  @moduledoc """
  The propagator for 'circuit' constraint.
  """

  ## 'args' are successor variables in the circuit
  defp update_state(args, current_state) do
    l = length(args)

    state =
      if !current_state do
        %{unfixed: MapSet.new(0..(l - 1)), circuit: List.duplicate(nil, l)}
      else
        current_state
      end

    Enum.reduce_while(
      state.unfixed,
      state,
      fn unfixed_idx,
         %{unfixed: unfixed_acc, circuit: circuit_acc} =
           acc ->
        v = Enum.at(args, unfixed_idx)

        if !current_state do
          initial_reduction(v, unfixed_idx, l)
        end

        updated_unfixed = MapSet.delete(unfixed_acc, unfixed_idx)

        if fixed?(v) do
          # forward_checking(args, updated_unfixed, v) do
          if false do
            ## If forward checking resulted in fixing other variables, recurse 
            ## TODO: consider doing forward checking as part of update_circuit
            ##
            {:halt, update_state(args, Map.put(state, :unfixed, updated_unfixed))}
          else
            case update_circuit(circuit_acc, unfixed_idx, min(v)) do
              :fail ->
                {:halt, :fail}

              :complete ->
                {:halt, :complete}

              {:incomplete, updated_circuit} ->
                {:cont,
                 %{
                   unfixed: updated_unfixed,
                   circuit: updated_circuit
                 }}
            end
          end
        else
          acc
        end
      end
    )
  end

  @impl true
  def variables(args) do
    Enum.map(args, fn x_el -> set_propagate_on(x_el, :fixed) end)
  end

  @impl true
  def filter(args) do
    filter(args, nil)
  end

  @impl true
  def filter(all_vars, state) do
    case update_state(all_vars, state) do
      :fail ->
        :fail

      :complete ->
        :passive

      new_state ->
        {:state, new_state}
    end
  end

  defp initial_reduction(var, succ_value, circuit_length) do
    ## Cut the domain of variable to adhere to circuit definition.
    ## The values are 0-based indices.
    ## The successor can't point to itself.
    removeBelow(var, 0)
    removeAbove(var, circuit_length - 1)
    remove(var, succ_value)
  end

  ## Update circuit at 'pos' position with 'value'
  defp update_circuit(circuit, pos, value) do
    List.update_at(circuit, pos, fn _ -> value end)
    |> then(fn updated -> check_circuit(updated, pos, value) end)
  end

  defp check_circuit(circuit, pos, value) do
    ## Follow the chain starting from 'pos'
    ## If the successor contains nil, stop
    ## Otherwise, 
    ## - stop if the successor value is a position we start with (loop detected)
    ## - if the length of the loop is less than the length of circuit, fail
    ## - otherwise, the circuit is completed
    l = length(circuit)

    Enum.reduce_while(1..l, {1, value}, fn _, {steps, succ_acc} ->
      case Enum.at(circuit, succ_acc) do
        nil ->
          {:halt, {:incomplete, circuit}}

        succ when succ == pos ->
          (steps < l - 1 && {:halt, :fail}) || {:halt, :complete}

        succ ->
          {:cont, {steps + 1, succ}}
      end
    end)
  end

  ## Remove the value from the unfixed vars.
  ## Collect the values from the variables that become fixed as a result of FWC.
  defp forward_checking(vars, unfixed_ids) do
    Enum.reduce_while(
      unfixed_ids,
      {unfixed_ids, []},
      fn idx, {unfixed_ids_acc, fixed_values} = acc ->
        v = Enum.at(vars, idx)

        if fixed?(v) do
          unfixed_ids_acc = Map.delete(unfixed_ids_acc, idx)
          remove_value(vars, unfixed_ids_acc, min(v))

          {:halt, forward_checking(vars, unfixed_ids_acc)}
        else
          {:cont, acc}
        end
      end
    )
  end

  defp remove_value(vars, unfixed_ids, value) do
    Enum.reduce(unfixed_ids, unfixed_ids, fn idx, acc ->
      (remove(Enum.at(vars, idx), value) == :fixed && MapSet.delete(unfixed_ids, idx)) ||
        unfixed_ids
    end)
  end
end
