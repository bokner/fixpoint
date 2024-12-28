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
  def filter(vars, state, changes) do
    new_state =
      (state && filter_impl(vars, state, changes)) ||
        initial_state(vars)

    (new_state == :resolved && :passive) ||
      {:state, new_state}
  end

  def initial_state(vars) do
    n = Arrays.size(vars)
    tree = make_array(2*n + 2)
    diffs = make_array(2*n + 2)
    hall = make_array(2*n + 2)
    bounds = make_array(2*n + 2)
    minrank = make_array(n)
    maxrank = make_array(n)

    {_idx, intervals} = Enum.reduce(vars, {0, []},
    fn var, {idx, interval_acc} ->
      {
        idx + 1,
        [%{idx: idx, min: Interface.min(var), max: Interface.max(var), minrank: 0, maxrank: 0} | interval_acc],
      }
    end)

    minsorted =
      intervals
      |> Enum.sort_by(fn %{min: min} -> min end)
      |> Arrays.new()

    maxsorted =
      intervals
      |> Enum.sort_by(fn %{max: max} -> max end)
      |> Arrays.new()

    last_min = minsorted[0].min
    last_max = maxsorted[0].max + 1
    last_bound = last_min - 2

    last_min_idx = 0
    last_max_idx = 0
    last_bound_idx = 0


    array_update(bounds, 0, last_bound)

    res = Enum.reduce(1..2*n, %{
      last_min: last_min,
      last_max: last_max,
      last_bound: last_bound,
      last_min_idx: last_min_idx,
      last_max_idx: last_max_idx,
      last_bound_idx: last_bound_idx},
    fn _idx, %{
      last_min: last_min,
      last_max: last_max,
      last_bound: last_bound,
      last_min_idx: last_min_idx,
      last_max_idx: last_max_idx,
      last_bound_idx: last_bound_idx} = acc ->
      cond do
        last_min_idx < n && last_min <= last_max ->
          ## LB values first
          acc = if last_min > last_bound do
            ## Record new bounds value and advance bounds index
            acc
            |> Map.put(:last_bound, last_min)
            |> Map.put(:last_bound_idx, acc.last_bound_idx + 1)
            |> tap(fn acc_ -> array_update(bounds, acc_.last_bound_idx, acc_.last_bound) end)
          else
            acc
          end
          ## Update minrank
          ## minsorted[]
          ## update_in(minsorted_acc[acc.last_min_idx], [:minrank], fn _ -> acc.last_bound_idx end)
          array_update(minrank, minsorted[acc.last_min_idx].idx, acc.last_bound_idx)
          ## Advance last min idx and record new last min value
          acc = Map.put(acc, :last_min_idx, last_min_idx + 1)
          if acc.last_min_idx < n do
            Map.put(acc, :last_min, minsorted[acc.last_min_idx].min)
          else
            acc
          end

        true ->
          ## Switch to UB values
          acc = if last_max > last_bound do
          ## Record new bounds value and advance bounds index
          acc
          |> Map.put(:last_bound, last_max)
          |> Map.put(:last_bound_idx, acc.last_bound_idx + 1)
          |> tap(fn acc_ -> array_update(bounds, acc_.last_bound_idx, acc_.last_bound) end)
        else
          acc
        end
        ## Update maxrank
        array_update(maxrank, maxsorted[acc.last_max_idx].idx, acc.last_bound_idx)
        ## Advance last max index and record new max value
        if last_max_idx + 1 < n do
          acc = Map.put(acc, :last_max_idx, last_max_idx + 1)
          Map.put(acc, :last_max, maxsorted[acc.last_max_idx].max + 1)
        else
          acc
        end

      end
    end)

    array_update(bounds, res.last_bound_idx + 1, array_get(bounds, res.last_bound_idx) + 2)

    %{
      n: n,
      bounds: bounds,
      n_bounds: res.last_bound_idx + 1,
      minrank: minrank,
      maxrank: maxrank,
      minsorted: minsorted,
      maxsorted: maxsorted,
      tree: tree,
      diffs: diffs,
      hall: hall
    }


  end


  defp filter_impl(
         vars,
         state,
         changes
       ) do
    {state1, changed1?} = filter_lower(vars, state)
    {state2, changed2?} = filter_upper(vars, state1)

    if changed1? || changed2? do
      filter_impl(vars, state2, changes)
    end

    {:state, state2}
  end

  def filter_lower(args, %{
    n: n,
    bounds: bounds,
    maxsorted: maxsorted,
    minrank: minrank,
    maxrank: maxrank,
    tree: tree,
    hall: hall,
    diffs: diffs
    } = state) do
    ## print_state(state)
    ## Initialize internal structures
    for idx <- 1..state.n_bounds + 1 do
      array_update(tree, idx, idx - 1)
      array_update(hall, idx, idx - 1)
      array_update(diffs, idx, array_get(bounds, idx) - array_get(bounds, idx - 1))
    end


    for i <- 0..n-1, reduce: false do
      filter? ->
      x = array_get(minrank, i)
      y = array_get(maxrank, i)
      z = pathmax(tree, x + 1)
      j = array_get(tree, z)

      array_update(diffs, z, array_get(diffs, z) - 1)
      z = if array_get(diffs, z) == 0 do
        array_update(tree, z, z + 1)
        z = pathmax(tree, array_get(tree, z))
        array_update(tree, z, j)
        z
      else
        z
      end

      pathset(tree, x + 1, z, z)

      if array_get(diffs, z) < array_get(bounds, z) - array_get(bounds, y), do: fail(:bounds)

      hall_x = array_get(hall, x)
      filter? = if hall_x > x do
        w = pathmax(hall, hall_x)
        var = args[maxsorted[i].idx]
        IO.inspect({var.name, Utils.domain_values(var), array_get(bounds, w)}, label: :removeBelow)

        res = removeBelow(var, array_get(bounds, w))
        pathset(hall, x, w, w)
        filter? || (res != :changed)
      else
        filter?
      end

      if array_get(diffs, z) == array_get(bounds, z) - array_get(bounds, y) do
        IO.inspect(%{hall: to_array(hall), y: y, j_1: j - 1})
        pathset(hall, array_get(hall, y), j - 1, y)
        array_update(hall, y, j - 1)
      end

      filter?
    end


    # %{
    #   tree: to_array(state.tree),
    #   hall: to_array(state.hall),
    #   diffs: to_array(state.diffs)
    # }
  end

  def filter_upper(args, %{
    n: n,
    bounds: bounds,
    minsorted: minsorted,
    minrank: minrank,
    maxrank: maxrank,
    tree: tree,
    hall: hall,
    diffs: diffs
    } = state) do
    ## Initialize internal structures
    for idx <- 0..state.n_bounds do
      array_update(tree, idx, idx + 1)
      array_update(hall, idx, idx + 1)
      array_update(diffs, idx, array_get(bounds, idx + 1) - array_get(bounds, idx))
    end

    print_state(state)

    for i <- n-1..0//-1, reduce: false do
      filter? ->
      x = array_get(maxrank, i)
      y = array_get(minrank, i)
      z = pathmin(tree, x - 1)
      j = array_get(tree, z)

      array_update(diffs, z, array_get(diffs, z) - 1)
      z = if array_get(diffs, z) == 0 do
        array_update(tree, z, z - 1)
        z = pathmin(tree, array_get(tree, z))
        array_update(tree, z, j)
        z
      else
        z
      end

      pathset(tree, x - 1, z, z)

      if array_get(diffs, z) < array_get(bounds, y) - array_get(bounds, z), do: fail(:bounds)

      hall_x = array_get(hall, x)
      filter? = if hall_x < x do
        w = pathmin(hall, hall_x)
        var = args[minsorted[i].idx]
        IO.inspect({var.name, Utils.domain_values(var), array_get(bounds, w) - 1}, label: :removeAbove)
        res = removeAbove(var, array_get(bounds, w) - 1)
        pathset(hall, x, w, w)
        filter? || (res != :changed)
      else
        filter?
      end

      if array_get(diffs, z) == array_get(bounds, y) - array_get(bounds, z) do
        IO.inspect(%{hall: to_array(hall), y: y, j_1: j + 1})
        pathset(hall, array_get(hall, y), j + 1, y)
        array_update(hall, y, j + 1)
      end

      filter?
    end


    # %{
    #   tree: to_array(state.tree),
    #   hall: to_array(state.hall),
    #   diffs: to_array(state.diffs)
    # }
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

  defp fail(reason) do
    throw({:fail, reason})
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

  def array_update(ref, zb_index, value) when is_reference(ref) and zb_index >= 0 and is_integer(value) do
    :atomics.put(ref, zb_index + 1, value)
  end

  def array_get(ref, zb_index) when is_reference(ref) and zb_index >= 0 do
    :atomics.get(ref, zb_index + 1)
  end

  def to_array(ref) do
    for i <- 1..:atomics.info(ref).size() do
      :atomics.get(ref, i)
    end
  end

  def print_state(state) do
    Map.put(state, :bounds, to_array(state.bounds))
    |> Map.put(:minrank, to_array(state.minrank))
    |> Map.put(:maxrank, to_array(state.maxrank))
    |> Map.put(:hall, to_array(state.hall))
    |> Map.put(:tree, to_array(state.tree))
    |> Map.put(:diffs, to_array(state.diffs))
    |> IO.inspect(label: :state)
  end

  def test do
    alias CPSolver.IntVariable, as: Variable
    vars =
      [x1, x2, x3, x4, x5, x6] =
      Enum.map(
        [{:x1, 3..4}, {:x2, 2..4}, {:x3, 3..4}, {:x4, 2..5}, {:x5, 3..6}, {:x6, 1..6}],
        fn {name, d} -> Variable.new(d, name: name) end
      )
      args = arguments(vars)
      state = initial_state(args)
      filter_lower(args, state)
      filter_upper(args, state)

      Enum.map(vars, fn v -> try do
        {v.name, Utils.domain_values(v)}
      catch _ -> :ok
    end
      end)
  end
end
