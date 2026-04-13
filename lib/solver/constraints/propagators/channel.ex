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
    ## so we prune everything that can't be such.
    ##
    removeBelow(x_var, 1)
    removeAbove(x_var, b_vars_num)
    %{unfixed_vars: 1..b_vars_num}
  end

  defp reduce(vars, %{unfixed_vars: unfixed_b_var_indices} = _state, _changes) do
    x_var = Vector.at(vars, 0)
    if fixed?(x_var) do
      ## We're done
      fix_booleans(min(x_var), vars, unfixed_b_var_indices)
      :completed
    else
      reduce_booleans(x_var, vars, unfixed_b_var_indices)
    end
  end

  defp fix_booleans(fixed_index, vars, unfixed_b_var_indices) do
    Enum.each(unfixed_b_var_indices,
      fn b_index ->
        fix_to = b_index == fixed_index && 1 || 0
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
              Enum.each(unfixed_b_vars_rest, fn idx -> fix(vars[idx], 0) end)
              {:halt, :completed}
          end
        else
          ## boolean var is not fixed
          {:cont,
            if contains?(x_var, b_index) do
              acc
            else
              fix(b_var, 0)
              unfixed_b_vars_rest
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
