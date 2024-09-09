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
  def bind(%{args: [var_array, var_index, var_value] = _args} = propagator, source, var_field) do
    bound_args =
      [
        Enum.map(var_array, fn var -> Propagator.bind_to_variable(var, source, var_field) end),
        Propagator.bind_to_variable(var_index, source, var_field),
        Propagator.bind_to_variable(var_value, source, var_field)
      ]

    Map.put(propagator, :args, bound_args)
  end

  @impl true
  def variables([var_array, var_index, var_value]) do
    Enum.map(var_array, fn var ->
      set_propagate_on(var, :domain_change)
    end) ++
      [
        set_propagate_on(var_index, :domain_change),
        set_propagate_on(var_value, :domain_change)
      ]
  end

  defp initial_state([[], _var_index, _var_value]) do
    throw(:fail)
  end

  defp initial_state([var_array, var_index, var_value]) do
    initial_reduction(var_array, var_index, var_value)
    {:state, %{}}
    # build_state(array2d, row_index, col_index, value, num_rows, num_cols)
  end

  defp initial_reduction(var_array, var_index, _var_value) do
    # var_index is an index in array2d,
    # so we trim D(var_index) to the size of array (0-based).
    removeBelow(var_index, 0)
    removeAbove(var_index, length(var_array) - 1)
  end

  @impl true
  def filter(args) do
    filter(args, initial_state(args))
  end

  def filter(args, nil) do
    filter(args, initial_state(args))
  end

  @impl true
  def filter([var_array, var_index, var_value] = _args, state) do
    filter_impl(var_array, var_index, var_value)
    state
  end

  defp filter_impl(var_array, var_index, var_value) do
    # Step 1
    ## For all variables in var_array, if no values in D(var_value)
    ## present in their domains, then the corresponding index has to be removed.
    value_domain = domain(var_value) |> Domain.to_list()
    index_domain = domain(var_index) |> Domain.to_list()

    total_value_intersection =
      Enum.reduce(index_domain, MapSet.new(), fn idx, intersection_acc ->
        case Enum.at(var_array, idx) do
          nil ->
            IO.inspect("Unexpected: no element at #{idx}")
            throw(:unexpected_no_element)

          elem_var ->
            elem_var_domain = domain(elem_var) |> Domain.to_list()
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
