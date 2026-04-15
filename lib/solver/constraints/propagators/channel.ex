defmodule CPSolver.Propagator.Channel do
  use CPSolver.Propagator

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
    x_var = Vector.at(vars, 0)
    b_vars_num = Vector.size(vars) - 1
    ## x_var has to be a position in b_vars list,
    ## so we prune values outside of range of b_vars.
    ##
    removeBelow(x_var, 1)
    removeAbove(x_var, b_vars_num)
    ## Make sure boolean variables have proper domains
    bool_var_indices = Range.to_list(1..b_vars_num)
    Enum.each(bool_var_indices, fn b_idx ->
      b_var = vars[b_idx]
      removeAbove(b_var, 1)
      removeBelow(b_var, 0)
    end)
    %{
      unfixed_vars: bool_var_indices
    }
  end

  defp reduce(vars, %{unfixed_vars: unfixed_b_var_indices} = _state, changes) when is_map(changes) do
    if map_size(changes) == 0 do
      full_reduction(vars, unfixed_b_var_indices)
    else
      partial_reduction(vars, unfixed_b_var_indices, changes)
    end
  end

  defp full_reduction(vars, unfixed_b_var_indices) do
    x_var = Vector.at(vars, 0)
    if fixed?(x_var) do
      ## We're done
      fix_booleans(min(x_var), vars, unfixed_b_var_indices)
      :completed
    else
      reduce_booleans(x_var, vars, unfixed_b_var_indices)
    end
  end

  defp partial_reduction(vars, unfixed_b_var_indices, changes) do
    full_reduction(vars, unfixed_b_var_indices)
  end

  defp fix_booleans(fixed_index, vars, unfixed_b_var_indices) do
    Enum.each(unfixed_b_var_indices,
      fn b_index ->
        fix_to = (b_index == fixed_index && 1 || 0)
        fix(vars[b_index], fix_to)
      end
    )
  end

  defp reduce_booleans(x_var, vars, unfixed_b_var_indices) do
      Enum.reduce_while(unfixed_b_var_indices, unfixed_b_var_indices,
        fn b_index, [_h | unfixed_b_vars_rest] = acc ->
        b_var = vars[b_index]

        if fixed?(b_var) do
          case min(b_var) do
            0 ->
              remove(x_var, b_index)
              {:cont, unfixed_b_vars_rest}

            1 ->
              ## We're done
              fix(x_var, b_index)
              ## fix the rest of b_vars to false
              Enum.each(acc, fn idx ->
                if idx != b_index do
                  fix(vars[idx], 0)
                end
              end)
              {:halt, :completed}
          end
        else
          ## boolean var is not fixed
          {:cont,
            if contains?(x_var, b_index) do
              acc
            else
              fix(b_var, 0)
              acc
            end
          }
        end
      end)
  end

  defp finalize(:completed) do
    :passive
  end

  defp finalize(unfixed_b_var_indices) do
    {:state,
      %{unfixed_vars: unfixed_b_var_indices}
    }
  end
end
