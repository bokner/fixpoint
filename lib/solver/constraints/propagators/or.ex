defmodule CPSolver.Propagator.Or do
  use CPSolver.Propagator

  @moduledoc """
  The propagator for 'or' constraint.
  Takes the list of boolean variables.
  Constraints to have at least one variable to be resolved to true.
  """

  @impl true
  def variables(args) do
    Enum.map(args, fn x_el -> set_propagate_on(x_el, :fixed) end)
  end

  @impl true
  def arguments(args) do
    Arrays.new(args, implementation: Aja.Vector)
  end

  @impl true
  def filter(all_vars, nil, _changes) do
    case initial_reduction(all_vars) do
      :resolved ->
        :passive

      unfixed ->
        (MapSet.size(unfixed) == 0 && fail()) ||
          filter(all_vars, %{unfixed: unfixed}, %{})
    end
  end

  def filter(all_vars, %{unfixed: unfixed} = _state, changes) when map_size(changes) == 0 do
    Enum.reduce_while(unfixed, unfixed, fn idx, unfixed_acc ->
      var = Arrays.get(all_vars, idx)
      if fixed?(var) do
        if min(var) == 1 do
          {:halt, :resolved}
        else
          {:cont, MapSet.delete(unfixed_acc, idx)}
        end
      else
        {:cont, unfixed_acc}
      end
    end)
    |> result
  end

  def filter(all_vars, %{unfixed: unfixed} = _state, changes) do
    Enum.reduce_while(changes, unfixed, fn {var_index, :fixed}, unfixed_acc ->
      if MapSet.member?(unfixed_acc, var_index) do
        if min(Arrays.get(all_vars, var_index)) == 1 do
          {:halt, :resolved}
        else
          {:cont, MapSet.delete(unfixed_acc, var_index)}
        end
      else
        {:cont, unfixed_acc}
      end
    end)
    |> result()
  end

  defp initial_reduction(all_vars) do
    Enum.reduce_while(0..(Arrays.size(all_vars) - 1), MapSet.new(), fn var_idx, candidates_acc ->
      var = Arrays.get(all_vars, var_idx)

      if fixed?(var) do
        case min(var) do
          0 -> {:cont, candidates_acc}
          1 -> {:halt, :resolved}
          _other_value -> throw(:not_boolean)
        end
      else
        {:cont, MapSet.put(candidates_acc, var_idx)}
      end
    end)
  end

  defp fail() do
    throw(:fail)
  end

  defp result(res) do
    case res do
      :resolved ->
        :passive

      unfixed ->
        (MapSet.size(unfixed) == 0 && fail()) ||
          {:state, %{unfixed: unfixed}}
    end
  end

end
