defmodule CPSolver.Propagator.ElementVar do
  use CPSolver.Propagator

  @moduledoc """
  The propagator for Element constraint.
  array[index] = value,
  where array is an array of variables.
  """
  def new(var_array, var_index, var_value) do
    new([var_array, var_index, var_value])
  end

  @impl true
  def arguments([var_array, var_index, var_value]) do
    [Arrays.new(var_array, implementation: Aja.Vector), var_index, var_value]
  end

  @impl true
  def bind(%{args: [var_array, var_index, var_value] = _args} = propagator, source, var_field) do
    bound_args =
      [
        Arrays.map(var_array, fn var -> Propagator.bind_to_variable(var, source, var_field) end),
        Propagator.bind_to_variable(var_index, source, var_field),
        Propagator.bind_to_variable(var_value, source, var_field)
      ]

    Map.put(propagator, :args, bound_args)
  end

  @impl true
  def variables([var_array, var_index, var_value]) do
    Enum.map(var_array, fn var ->
      set_propagate_on(var, :fixed)
    end) ++
      [
        set_propagate_on(var_index, :domain_change),
        set_propagate_on(var_value, :domain_change)
      ]
  end

  defp initial_reduction([], _var_index, _var_value, _state, _changes) do
    throw(:fail)
  end

  defp initial_reduction(var_array, var_index, var_value, state, changes) do
    # var_index is an index in array2d,
    # so we trim D(var_index) to the size of array (0-based).
    removeBelow(var_index, 0)
    removeAbove(var_index, Arrays.size(var_array) - 1)
    reduction(var_array, var_index, var_value, state, changes)
  end

  @impl true
  def filter([var_array, var_index, var_value] = _args, state, changes) do
    new_state = state || %{var_index_position: Arrays.size(var_array)}

    res =
      (state && filter_impl(var_array, var_index, var_value, new_state, changes)) ||
        initial_reduction(var_array, var_index, var_value, new_state, changes)

    (res == :passive && :passive) || {:state, new_state}
  end

  defp filter_impl(
         var_array,
         var_index,
         var_value,
         %{var_index_position: idx_position} = state,
         changes
       ) do
    ## Run reduction when either of index or value variables are fixed
    map_size(changes) > 0 &&
      (Map.has_key?(changes, idx_position) || Map.has_key?(changes, idx_position + 1)) &&
      reduction(var_array, var_index, var_value, state, changes)
  end

  defp reduction(var_array, var_index, var_value, _state, _changes) do
    index_domain = domain_values(var_index)

    # Step 1
    ## For all variables in var_array, if no values in D(var_value)
    ## present in their domains, then the corresponding index has to be removed.
    value_domain = domain_values(var_value)

    total_value_intersection =
      Enum.reduce(index_domain, MapSet.new(), fn idx, intersection_acc ->
        case Arrays.get(var_array, idx) do
          nil ->
            IO.inspect("Unexpected: no element at #{idx}")
            throw(:unexpected_no_element)

          elem_var ->
            elem_var_domain = domain_values(elem_var)
            intersection = MapSet.intersection(value_domain, elem_var_domain)

            (MapSet.size(intersection) == 0 && remove(var_index, idx) && intersection_acc) ||
              MapSet.union(intersection, intersection_acc)
        end
      end)

    ## Step 2
    ## `total_value_intersection` has domain values from D(var_value)
    ## such that each of them is present in at least one domain of variables
    ## of `var_array`
    ## Hence, we can remove values that are not in `total_value_intersection` from
    ## D(var_value)

    Enum.each(value_domain, fn val ->
      !MapSet.member?(total_value_intersection, val) && remove(var_value, val)
    end)
  end
end
