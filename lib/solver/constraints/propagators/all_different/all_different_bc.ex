defmodule CPSolver.Propagator.AllDifferent.BC do
  use CPSolver.Propagator

  alias CPSolver.Utils

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
  def filter(vars, _state, changes) do
        updated_state = initial_state(vars)
        filter_impl(vars, updated_state, changes)
        {:state, updated_state}
  end

  defp initial_state(vars) do
    n = Arrays.size(vars)
    lbs = make_array(n)
    ubs = make_array(n)

    {_idx, intervals} =
      Enum.reduce(vars, {0, []}, fn var, {idx, interval_acc} ->
        {
          idx + 1,
          [
            %{
            idx: idx,
            min: Interface.min(var) |> tap(fn lb -> array_update(lbs, idx, lb) end),
            max: Interface.max(var) |> tap(fn ub -> array_update(ubs, idx, ub) end)
            } | interval_acc]
        }
      end)



    tree = make_array(2 * n + 2)
    diffs = make_array(2 * n + 2)
    hall = make_array(2 * n + 2)
    bounds = make_array(2 * n + 2)
    minrank = make_array(n)
    maxrank = make_array(n)

    minsorted = make_array(n)

      intervals
      |> Enum.sort_by(fn %{min: min} -> min end)
      |> Enum.reduce(0, fn %{idx: idx}, idx_acc ->
        array_update(minsorted, idx_acc, idx)
        idx_acc + 1
      end)

      maxsorted = make_array(n)

      intervals
      |> Enum.sort_by(fn %{max: max} -> max end)
      |> Enum.reduce(0, fn %{idx: idx}, idx_acc ->
        array_update(maxsorted, idx_acc, idx)
        idx_acc + 1
      end)


    last_min = array_get(lbs, array_get(minsorted, 0))
    last_max = array_get(ubs, array_get(maxsorted, 0)) + 1
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
              ##

              array_update(minrank, array_get(minsorted, acc.last_min_idx), acc.last_bound_idx)
              ## Advance last min idx and record new last min value
              acc = Map.put(acc, :last_min_idx, last_min_idx + 1)

              if acc.last_min_idx < n do
                Map.put(acc, :last_min, array_get(lbs, array_get(minsorted, acc.last_min_idx)))
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

              array_update(maxrank, array_get(maxsorted, acc.last_max_idx), acc.last_bound_idx)
              ## Advance last max index and record new max value
              if last_max_idx + 1 < n do
                acc = Map.put(acc, :last_max_idx, last_max_idx + 1)
                Map.put(acc, :last_max, array_get(ubs, array_get(maxsorted, acc.last_max_idx)) + 1)
              else
                acc
              end
          end
        end
      )

    array_update(bounds, res.last_bound_idx + 1, array_get(bounds, res.last_bound_idx) + 2)

    %{
      n: n,
      bounds: bounds,
      n_bounds: res.last_bound_idx,
      minsorted: minsorted,
      maxsorted: maxsorted,
      minrank: minrank,
      maxrank: maxrank,
      tree: tree,
      diffs: diffs,
      hall: hall
    }
  end

  defp filter_impl(
         vars,
         state,
         _changes
       ) do

      lb_change? = while(fn -> filter_lower(vars, state) end)
      ub_change? = while(fn -> filter_upper(vars, state) end)

      (lb_change? || ub_change?)
       #&& filter_impl(vars, state, changes)

    state
  end

  defp while(fun) do
    fun.() && while(fun)
  end

  defp filter_lower(
         args,
         %{
           n: n,
           bounds: bounds,
           maxsorted: maxsorted,
           minrank: minrank,
           maxrank: maxrank,
           tree: tree,
           hall: hall,
           diffs: diffs
         } = state
       ) do
    ## Initialize internal structures
    for idx <- 1..(state.n_bounds + 1) do
      array_update(tree, idx, idx - 1)
      array_update(hall, idx, idx - 1)
      array_update(diffs, idx, array_get(bounds, idx) - array_get(bounds, idx - 1))
    end

    for i <- 0..(n - 1), reduce: false do
      filter_acc? ->
        var_idx = array_get(maxsorted, i)
        x = array_get(minrank, var_idx)
        y = array_get(maxrank, var_idx)
        z = pathmax(tree, x + 1)
        j = array_get(tree, z)

        array_add(diffs, z, - 1)

        z =
          if array_get(diffs, z) == 0 do
            array_update(tree, z, z + 1)

            pathmax(tree, array_get(tree, z))
            |> tap(fn z -> array_update(tree, z, j) end)
          else
            z
          end

        pathset(tree, x + 1, z, z)

        if array_get(diffs, z) < array_get(bounds, z) - array_get(bounds, y), do: fail()

        hall_x = array_get(hall, x)

        if hall_x > x do
          w = pathmax(hall, hall_x)
          res = removeBelow(args[var_idx], array_get(bounds, w))
          pathset(hall, x, w, w)
          filter_acc? || res != :no_change
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
           minsorted: minsorted,
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

    for i <- (n - 1)..0//-1, reduce: false do
      filter_acc? ->
        var_idx = array_get(minsorted, i)
        x = array_get(maxrank, var_idx)
        y = array_get(minrank, var_idx)
        z = pathmin(tree, x - 1)
        j = array_get(tree, z)

        array_add(diffs, z, - 1)

        z =
          if array_get(diffs, z) == 0 do
            array_update(tree, z, z - 1)

            pathmin(tree, array_get(tree, z))
            |> tap(fn z -> array_update(tree, z, j) end)
          else
            z
          end

        pathset(tree, x - 1, z, z)

        if array_get(diffs, z) < array_get(bounds, y) - array_get(bounds, z), do: fail()

        hall_x = array_get(hall, x)

        if hall_x < x do
          w = pathmin(hall, hall_x)
          res = removeAbove(args[var_idx], array_get(bounds, w) - 1)
          pathset(hall, x, w, w)
          filter_acc? || res != :no_change
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

  defp fail() do
    throw(:fail)
  end

  defp make_array(arity) when is_integer(arity) do
    :atomics.new(arity, signed: true)
  end

  defp make_array(list) when is_list(list) do
    ref = make_array(length(list))

    Enum.reduce(list, 1, fn el, idx ->
      :atomics.put(ref, idx, el)
      idx + 1
    end)

    ref
  end

  defp array_update(ref, zb_index, value)
       when is_reference(ref) and zb_index >= 0 and is_integer(value) do
    :atomics.put(ref, zb_index + 1, value)
  end

  defp array_add(ref, zb_index, value) when is_reference(ref) and zb_index >=0 and is_integer(value) do
    :atomics.add(ref, zb_index + 1, value)
  end

  defp array_get(ref, zb_index) when is_reference(ref) and zb_index >= 0 do
    :atomics.get(ref, zb_index + 1)
  end

  defp to_array(ref) do
    for i <- 1..:atomics.info(ref).size() do
      :atomics.get(ref, i)
    end
  end

  defp print_state(state) do
    Map.put(state, :bounds, to_array(state.bounds))
    |> Map.put(:minsorted, state.minsorted)
    |> Map.put(:maxsorted, state.maxsorted)
    |> Map.put(:minrank, to_array(state.minrank))
    |> Map.put(:maxrank, to_array(state.maxrank))
    |> Map.put(:hall, to_array(state.hall))
    |> Map.put(:tree, to_array(state.tree))
    |> Map.put(:diffs, to_array(state.diffs))
    |> IO.inspect(label: :state)
  end

  def test do
    alias CPSolver.IntVariable, as: Variable
    alias CPSolver.Utils

    vars =
      Enum.map(
        [{:x1, 3..4}, {:x2, 2..4}, {:x3, 3..4}, {:x4, 2..5}, {:x5, 3..6}, {:x6, 1..6}],
        # [{:x1, 1..1}, {:x2, 2..2}, {:x3, 3}],
        fn {name, d} -> Variable.new(d, name: name) end
      )

    args = arguments(vars)
    state = initial_state(args)
    print_state(state)

    filter(args, state, :ignore)
    |> tap(fn r -> IO.inspect(r, label: :state) end)

    Enum.map(vars, fn v ->
      try do
        {v.name, Utils.domain_values(v)}
      catch
        _ -> {:fail, v.name}
      end
    end)
  end
end
