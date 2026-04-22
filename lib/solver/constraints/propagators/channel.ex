defmodule CPSolver.Propagator.Channel do
  use CPSolver.Propagator

  def new(x, bools) do
    b_vars_num = length(bools)
    removeBelow(x, 1)
    removeAbove(x, b_vars_num)

    Enum.each(bools, fn b_var ->
      removeAbove(b_var, 1)
      removeBelow(b_var, 0)
    end)

    new([x | bools])
  end

  @impl true
  def variables([x | b_vars]) do
    [
      set_propagate_on(x, :domain_change)
      | Enum.map(b_vars, fn b_var -> set_propagate_on(b_var, :fixed) end)
    ]
  end

  @impl true
  def arguments(args) do
    Vector.new(args)
  end

  @impl true
  def filter(vars, state, changes) do
    state = state || initial_state(vars)

    reduce(vars, state, changes)
    |> finalize()
  end

  defp initial_state(vars) do
    bool_var_indices = MapSet.new(1..(Vector.size(vars) - 1))

    %{
      unfixed_vars: bool_var_indices
    }
  end

  defp reduce(vars, %{unfixed_vars: unfixed_b_var_indices} = _state, changes) do
    x_var = vars[0]
    ## Apply changes
    stage1_results =
      Enum.reduce_while(changes, unfixed_b_var_indices, fn
        {0, :fixed}, acc ->
          ## x is fixed, we're done
          {:halt, {:entailed, min(x_var), acc}}

        {0, _other_x_change}, acc ->
          {:cont,
           Enum.reduce(domain_values(x_var), acc, fn idx, acc2 ->
             if idx in acc2 do
               acc2
             else
               fix(vars[idx], 0)
               MapSet.delete(acc2, idx)
             end
           end)}

        {b_var_idx, :fixed}, acc ->
          acc = MapSet.delete(acc, b_var_idx)
          ## one of booleans is fixed
          b_min = min(vars[b_var_idx])

          if b_min == 1 do
            fix(x_var, b_var_idx)
            {:halt, {:entailed, b_var_idx, acc}}
          else
            case remove(x_var, b_var_idx) do
              :fixed ->
                {:halt, {:entailed, min(x_var), acc}}

              _ ->
                {:cont, acc}
            end
          end
      end)

    ## Stage 2 : iterate through the rest of unfixed indices
    case stage1_results do
      {:entailed, x_value, unfixed_bool_indices} ->
        fix_booleans(x_value, vars, unfixed_bool_indices)
        :entailed

      unfixed_bool_indices ->
        if fixed?(x_var) do
          fix_booleans(min(x_var), vars, unfixed_bool_indices)
          :entailed
        else
          reduce_stage2(x_var, vars, unfixed_bool_indices)
        end
    end
  end

  defp fix_booleans(fixed_index, vars, unfixed_b_var_indices) do
    Enum.each(
      unfixed_b_var_indices,
      fn b_index ->
        fix_to = (b_index == fixed_index && 1) || 0
        fix(vars[b_index], fix_to)
      end
    )
  end

  defp reduce_stage2(x_var, vars, unfixed_bool_indices) do
    Enum.reduce_while(unfixed_bool_indices, unfixed_bool_indices, fn b_var_idx, acc ->
      b_var = vars[b_var_idx]

      if fixed?(b_var) do
        if min(b_var) == 1 do
          fix(x_var, b_var_idx)
          fix_booleans(b_var_idx, vars, acc)
          {:halt, :entailed}
        else
          case remove(x_var, b_var_idx) do
            :fixed ->
              {:halt, :entailed}

            _ ->
              {:cont, acc}
          end
        end
      else
        if contains?(x_var, b_var_idx) do
          {:cont, acc}
        else
          fix(b_var, 0)
          {:cont, MapSet.delete(acc, b_var_idx)}
        end
      end
    end)
  end

  defp finalize(:entailed) do
    :passive
  end

  defp finalize(unfixed_b_var_indices) do
    if Enum.empty?(unfixed_b_var_indices) do
      :passive
    else
      {:state, %{unfixed_vars: unfixed_b_var_indices}}
    end
  end
end
