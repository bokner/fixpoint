defmodule CPSolver.Propagator.AllDifferent.BC do
  use CPSolver.Propagator

  alias CPSolver.Utils
  import CPSolver.Utils.MutableArray

  alias CPSolver.Utils.MutableArray
  alias CPSolver.Utils.MutableOrder

  @moduledoc """
  A fast and simple algorithm for bounds consistency of the alldifferent constraint
    (L´opez et al., 2003)
  """
  @impl true
  def arguments(args) do
    Arrays.new(args, implementation: Aja.Vector)
  end

  @impl true
  def variables(args) do
    Enum.map(args, fn x_el -> set_propagate_on(x_el, :bound_change) end)
  end

  @impl true
  @doc "Needs a reset so not to carry over the mutable arrays"
  def reset(vars, _state, _opts) do
    initialize_state(vars)
  end

  @impl true
  def filter(vars, state, changes) do
    updated_state = apply_changes(vars, state, changes)
    filter_impl(vars, updated_state, changes)
    {:state, updated_state}
  end

  defp initialize_state(vars) do
    n = Arrays.size(vars)

    {_, lbs, ubs} =
      Enum.reduce(vars, {0, [], []}, fn var, {idx, min_acc, max_acc} ->
        {idx + 1, [min(var) | min_acc], [max(var) | max_acc]}
      end)

    %{
      n: n,
      minsorted_order: MutableOrder.new(Enum.reverse(lbs)),
      maxsorted_order: MutableOrder.new(Enum.reverse(ubs))
    }
  end

  defp apply_changes(vars, nil, changes) do
    apply_changes(vars, initialize_state(vars), changes || %{})
  end

  defp apply_changes(
         vars,
         %{minsorted_order: minsorted, maxsorted_order: maxsorted} = state,
         changes
       ) do

    #Enum.each(changes, fn {var_idx, domain_change} -> apply_change(vars[var_idx], var_idx, state, domain_change) end)
    #n = state.n

    state
    #Map.merge(state, internals)
  end

  defp apply_change(var, var_index, %{minsorted_order: minsorted} = _state, :min_change) do
    #MutableOrder.update(minsorted, {var_index, min(var)})
  end

  defp apply_change(var, var_index, %{maxsorted_order: maxsorted} = _state, :max_change) do
    #MutableOrder.update(maxsorted, {var_index, max(var)})
  end

  defp apply_change(var, var_index, state, domain_change)
       when domain_change in [:fixed, :bound_change] do
    #apply_change(var, var_index, state, :min_change)
    #apply_change(var, var_index, state, :max_change)
  end

  def prepare(
        %{
          n: n,
          minsorted_order: minsorted,
          maxsorted_order: maxsorted
        } = state
      ) do

        tree = make_array(2 * n + 2)
        diffs = make_array(2 * n + 2)
        hall = make_array(2 * n + 2)
        bounds =  make_array(2 * n + 2)
        minrank = make_array(n)
        maxrank = make_array(n)

    last_min = MutableOrder.get(minsorted, 0)
    last_max = MutableOrder.get(maxsorted, 0) + 1
    last_bound = last_min - 2

    last_min_idx = 0
    last_max_idx = 0
    last_bound_idx = 0

    array_update(bounds, 0, last_bound)

    res =
      Enum.reduce(
        1..(2 * n),
        %{
          last_min: last_min,
          last_max: last_max,
          last_bound: last_bound,
          last_min_idx: last_min_idx,
          last_max_idx: last_max_idx,
          last_bound_idx: last_bound_idx
        },
        fn _idx,
           %{
             last_min: last_min,
             last_max: last_max,
             last_bound: last_bound,
             last_min_idx: last_min_idx,
             last_max_idx: last_max_idx
           } = acc ->
          cond do
            last_min_idx < n && last_min <= last_max ->
              ## LB values first
              acc =
                if last_min > last_bound do
                  ## Record new bounds value and advance bounds index
                  acc
                  |> Map.put(:last_bound, last_min)
                  |> Map.put(:last_bound_idx, acc.last_bound_idx + 1)
                  |> tap(fn acc_ -> array_update(bounds, acc_.last_bound_idx, acc_.last_bound) end)
                else
                  acc
                end

              ## Update minrank
              array_update(
                minrank,
                array_get(minsorted.sort_index, acc.last_min_idx),
                acc.last_bound_idx
              )

              ## Advance last min idx and record new last min value
              acc = Map.put(acc, :last_min_idx, last_min_idx + 1)

              if acc.last_min_idx < n do
                Map.put(acc, :last_min, MutableOrder.get(minsorted, acc.last_min_idx))
              else
                acc
              end

            true ->
              ## Switch to UB values
              acc =
                if last_max > last_bound do
                  ## Record new bounds value and advance bounds index
                  acc
                  |> Map.put(:last_bound, last_max)
                  |> Map.put(:last_bound_idx, acc.last_bound_idx + 1)
                  |> tap(fn acc_ -> array_update(bounds, acc_.last_bound_idx, acc_.last_bound) end)
                else
                  acc
                end

              ## Update maxrank
              array_update(
                maxrank,
                array_get(maxsorted.sort_index, acc.last_max_idx),
                acc.last_bound_idx
              )

              ## Advance last max index and record new max value
              if last_max_idx + 1 < n do
                acc = Map.put(acc, :last_max_idx, last_max_idx + 1)

                Map.put(
                  acc,
                  :last_max,
                  MutableOrder.get(maxsorted, acc.last_max_idx) + 1
                )
              else
                acc
              end
          end
        end
      )

    array_update(bounds, res.last_bound_idx + 1, array_get(bounds, res.last_bound_idx) + 2)

    Map.put(state, :n_bounds, res.last_bound_idx)
    |> Map.put(:tree, tree)
    |> Map.put(:diffs, diffs)
    |> Map.put(:hall, hall)
    |> Map.put(:bounds, bounds)
    |> Map.put(:minrank, minrank)
    |> Map.put(:maxrank, maxrank)
  end

  defp filter_impl(
         vars,
         state,
         changes
       ) do
    state = prepare(state)
    filtered_lower? = filter_lower(vars, state)
    filtered? = filter_upper(vars, state) || filtered_lower?
    filtered? && filter_impl(vars, state, changes)

    state
  end

  defp filter_lower(
         args,
         %{
           n: n,
           bounds: bounds,
           n_bounds: n_bounds,
           minsorted_order: minsorted,
           maxsorted_order: maxsorted,
           minrank: minrank,
           maxrank: maxrank,
           tree: tree,
           hall: hall,
           diffs: diffs
         } = state
       ) do
    ## Initialize internal structures
    for idx <- 1..(n_bounds + 1) do
      array_update(tree, idx, idx - 1)
      array_update(hall, idx, idx - 1)
      array_update(diffs, idx, array_get(bounds, idx) - array_get(bounds, idx - 1))
    end

    # IO.inspect({self(), print_state(state)}, label: :state_lower)
    # for {{var_idx, _ub}, pos} <- Enum.with_index(MutableOrder.to_sorted(maxsorted, :asc)), reduce: false do
    for i <- 0..(n - 1), reduce: false do
      filter_acc? ->
        var_idx = array_get(maxsorted.sort_index, i)
        x = array_get(minrank, var_idx)
        y = array_get(maxrank, var_idx)
        z = pathmax(tree, x + 1)
        j = array_get(tree, z)

        array_add(diffs, z, -1)

        z =
          if array_get(diffs, z) == 0 do
            array_update(tree, z, z + 1)

            pathmax(tree, array_get(tree, z))
            |> tap(fn z -> array_update(tree, z, j) end)
          else
            z
          end

        pathset(tree, x + 1, z, z)

        if array_get(diffs, z) < array_get(bounds, z) - array_get(bounds, y),
          do: fail(state, "Filter lower failure")

        hall_x = array_get(hall, x)

        if hall_x > x do
          w = pathmax(hall, hall_x)
          pathset(hall, x, w, w)
          new_min = array_get(bounds, w)
          res = removeBelow(args[var_idx], new_min)

          filter_acc? ||
            (res != :no_change)
            |> tap(fn changed? ->
              changed? && MutableOrder.update(minsorted, {var_idx, new_min})
            end)

          # ]
        else
          filter_acc?
        end
        |> tap(fn _ ->
          if array_get(diffs, z) == array_get(bounds, z) - array_get(bounds, y) do
            pathset(hall, array_get(hall, y), j - 1, y)
            array_update(hall, y, j - 1)
          end
        end)
    end
  end

  defp filter_upper(
         args,
         %{
           n: n,
           bounds: bounds,
           maxsorted_order: maxsorted,
           minsorted_order: minsorted,
           minrank: minrank,
           maxrank: maxrank,
           tree: tree,
           hall: hall,
           diffs: diffs
         } = state
       ) do
    ## Initialize internal structures
    for idx <- 0..state.n_bounds do
      array_update(tree, idx, idx + 1)
      array_update(hall, idx, idx + 1)
      array_update(diffs, idx, array_get(bounds, idx + 1) - array_get(bounds, idx))
    end

    for i <- 0..(n - 1), reduce: false do
      filter_acc? ->
        var_idx = array_get(minsorted.sort_index, n - 1 - i)
        x = array_get(maxrank, var_idx)
        y = array_get(minrank, var_idx)
        z = pathmin(tree, x - 1)
        j = array_get(tree, z)

        array_add(diffs, z, -1)

        z =
          if array_get(diffs, z) == 0 do
            array_update(tree, z, z - 1)

            pathmin(tree, array_get(tree, z))
            |> tap(fn z -> array_update(tree, z, j) end)
          else
            z
          end

        pathset(tree, x - 1, z, z)

        if array_get(diffs, z) < array_get(bounds, y) - array_get(bounds, z),
          do: fail(state, "Filter upper failure")

        hall_x = array_get(hall, x)

        if hall_x < x do
          w = pathmin(hall, hall_x)
          pathset(hall, x, w, w)
          new_max = array_get(bounds, w) - 1
          res = removeAbove(args[var_idx], new_max)

          filter_acc? ||
            (res != :no_change)
            |> tap(fn changed? ->
              changed? && MutableOrder.update(maxsorted, {var_idx, new_max})
            end)
        else
          filter_acc?
        end
        |> tap(fn _ ->
          if array_get(diffs, z) == array_get(bounds, y) - array_get(bounds, z) do
            pathset(hall, array_get(hall, y), j + 1, y)
            array_update(hall, y, j + 1)
          end
        end)
    end
  end

  defp pathmax(tree, i) do
    case array_get(tree, i) do
      n when n > i -> pathmax(tree, n)
      _le -> i
    end
  end

  defp pathmin(tree, i) do
    case array_get(tree, i) do
      n when n < i -> pathmin(tree, n)
      _ge -> i
    end
  end

  defp pathset(tree, path_start, path_end, to) do
    next = path_start
    prev = next

    if prev == path_end do
      tree
    else
      next = array_get(tree, prev)
      array_update(tree, prev, to)
      pathset(tree, next, path_end, to)
    end
  end

  defp fail(_state, _reason) do
    throw(:fail)
  end

  def print_state(state) do
    Map.put(state, :bounds, to_array(state.bounds))
    |> Map.put(:minsorted_values, to_array(state.minsorted_order.values))
    |> Map.put(:minsorted_order, to_array(state.minsorted_order.sort_index))
    |> Map.put(:maxsorted_values, to_array(state.maxsorted_order.values))
    |> Map.put(:maxsorted_order, to_array(state.maxsorted_order.sort_index))
    |> Map.put(:minrank, to_array(state.minrank))
    |> Map.put(:maxrank, to_array(state.maxrank))
    |> Map.put(:hall, to_array(state.hall))
    |> Map.put(:tree, to_array(state.tree))
    |> Map.put(:diffs, to_array(state.diffs))

    # |> IO.inspect(label: :state)
  end

  defp make_array(arity) when is_integer(arity) do
    MutableArray.new(arity)
  end

  def test do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Utils

    # vars =
    #   Enum.map(
    #     [{:x1, 3..4}, {:x2, 2..4}, {:x3, 3..4}, {:x4, 2..5}, {:x5, 3..6}, {:x6, 1..6}],
    #     # [{:x1, 1..1}, {:x2, 2..2}, {:x3, 3}],
    #     fn {name, d} -> Variable.new(d, name: name) end
    #   )

    vars = Enum.map([1, 1..2, 1..4, [1, 2, 4, 5]], fn d -> Variable.new(d) end)

    args = arguments(vars)
    state = apply_changes(args, nil, %{}) |> prepare()
    print_state(state)

    filter(args, state, %{})
    |> tap(fn r -> IO.inspect(r, label: :state) end)

    {state,
     Enum.map(vars, fn v ->
       try do
         {v.name, Utils.domain_values(v)}
       catch
         _ -> {:fail, v.name}
       end
     end)}
  end
end
