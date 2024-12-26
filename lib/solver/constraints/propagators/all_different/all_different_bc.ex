defmodule CPSolver.Propagator.AllDifferent.BC do
  use CPSolver.Propagator

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
    ## Create a list of bounds.
    ## First, create a list L of unique values over all min(v), max(v) + 1, s.t. v is in vars
    ## Prepend resulting list with min(L) - 2
    ## Append max(L) + 2
    {mins, maxes, bounds} =
      Enum.reduce(
        vars,
        {Arrays.new(), Arrays.new(), MapSet.new()},
        fn var, {mins_acc, maxes_acc, bounds_acc} ->
          min_v = min(var)
          max_v = max(var)
          bounds_acc = MapSet.put(bounds_acc, min_v) |> MapSet.put(max_v + 1)

          {
            Arrays.append(mins_acc, min_v),
            Arrays.append(maxes_acc, max_v),
            bounds_acc
          }
        end
      )

    ## Min and max ranks: 0-based indices of min and max+1 in `bounds` list
    ## TODO: should be doing it in one pass...
    ## Note: we add 1 to rank indices because the bounds will be prepended with an additional element
    {min_rank, max_rank} =
      Enum.reduce(0..(Arrays.size(mins) - 1), {Arrays.new(), Arrays.new()}, fn idx,
                                                                               {min_rank_acc,
                                                                                max_rank_acc} ->
        {
          Arrays.append(min_rank_acc, Enum.find_index(bounds, fn b -> b == mins[idx] end) + 1),
          Arrays.append(
            max_rank_acc,
            Enum.find_index(bounds, fn b -> b == maxes[idx] + 1 end) + 1
          )
        }
      end)

    {min_b, max_b} = Enum.min_max(bounds)
    n_bounds = MapSet.size(bounds)

    %{
      bounds: bounds |> MapSet.put(min_b - 2) |> MapSet.put(max_b + 2) |> Arrays.new(),
      n_bounds: n_bounds,
      minimums: mins,
      maximums: maxes,
      min_rank: min_rank,
      max_rank: max_rank
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

  def filter_lower(
        vars,
        %{bounds: bounds, maximums: maxes, min_rank: min_rank, max_rank: max_rank} = state
      ) do
    ## t -Tree links
    ## d - differences
    ## h - Hall interval links
    ##
    {t, d, h} =
      Enum.reduce(
        1..state.n_bounds,
        {Arrays.new([0]), Arrays.new([0]), Arrays.new([0])},
        fn idx, {t_acc, d_acc, h_acc} ->
          {
            Arrays.append(t_acc, idx - 1),
            Arrays.append(d_acc, bounds[idx] - bounds[idx - 1]),
            Arrays.append(h_acc, idx - 1)
          }
        end
      )

    max_sorted =
      maxes
      |> Enum.with_index(0)
      |> Enum.sort_by(fn {max_v, _idx} -> max_v end)
      |> Enum.map(fn {_max, idx} -> idx end)

    for idx <- max_sorted do
      x = min_rank[idx]
      y = max_rank[idx]
      z = pathmax(t, x + 1)
      j = t[z]


    #   for (int i = 1; i <= nbBounds + 1; i++) {
    #     t[i] = h[i] = i - 1;
    #     d[i] = bounds[i] - bounds[i - 1];
    # }
    # for (int i = 0; i < this.vars.length; i++) {
    #     int x = maxsorted[i].minrank;
    #     int y = maxsorted[i].maxrank;
    #     int z = pathmax(t, x + 1);
    #     int j = t[z];

    #     if (--d[z] == 0) {
    #         t[z] = z + 1;
    #         z = pathmax(t, t[z]);
    #         t[z] = j;
    #     }
    #     pathset(t, x + 1, z, z);
    #     if (d[z] < bounds[z] - bounds[y]) {
    #         fail()
    #     }
    #     if (h[x] > x) {
    #         int w = pathmax(h, h[x]);
    #         if (maxsorted[i].var.updateLowerBound(bounds[w], aCause)) {
    #             filter = true;
    #             maxsorted[i].lb = maxsorted[i].var.getLB();//bounds[w];
    #         }
    #         pathset(h, x, w, w);
    #     }
    #     if (d[z] == bounds[z] - bounds[y]) {
    #         pathset(h, h[y], j - 1, y);
    #         h[y] = j - 1;
    #     }
    # }
    end
  end

  defp filter_upper(vars, state) do
  end

  defp pathmax(tree, i) do
    case tree[i] do
      n when n > i -> pathmax(tree, n)
      _leq -> i
    end
  end

  defp fail() do
    throw(:fail)
  end
end
