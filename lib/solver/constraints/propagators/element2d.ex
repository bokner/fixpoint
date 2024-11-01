defmodule CPSolver.Propagator.Element2D do
  use CPSolver.Propagator

  import CPSolver.Utils

  @moduledoc """
  The propagator for Element2D constraint.
  array2d[row_index][col_index] = value
  """
  def new(array2d, row_index, col_index, value) do
    new([array2d, row_index, col_index, value])
  end

  @impl true
  def variables([_array2d, row_index, col_index, value]) do
    [
      set_propagate_on(row_index, :domain_change),
      set_propagate_on(col_index, :domain_change),
      set_propagate_on(value, :domain_change)
    ]
  end

  defp initial_state([[], _row_index, _col_index, _value]) do
    throw(:fail)
  end

  defp initial_state([array2d, row_index, col_index, value]) do
    num_rows = length(array2d)
    num_cols = length(hd(array2d))

    initial_reduction(array2d, row_index, col_index, value, num_rows, num_cols)
    build_state(array2d, row_index, col_index, value, num_rows, num_cols)
  end

  def build_state(array2d, row_index, col_index, value, num_rows, num_cols) do
    ## Build a state graph.
    ## Three sets of vertices: ([{:value, value}], [{:row_index, value}], [{:col_index, value}])
    ## with edges from {:value, z_value} to {:row_index, x_value},
    ## where z_value is present in x_value row of array2d.
    ## Likewise, with edges from {:value, z_value} to {:col_index, y_value},
    ## where z_value is present in y_value column of array2d.
    for i <- 0..(num_rows - 1), j <- 0..(num_cols - 1), reduce: Graph.new() do
      acc ->
        if contains?(row_index, i) && contains?(col_index, j) do
          table_value = Enum.at(array2d, i) |> Enum.at(j)

          if contains?(value, table_value) do
            acc
            |> Graph.add_edge({:value, table_value}, {:row_index, i}, label: {:col_index, j})
            |> Graph.add_edge({:value, table_value}, {:col_index, j}, label: {:row_index, i})
          else
            acc
          end
        else
          acc
        end
    end
  end

  defp initial_reduction(array2d, row_index, col_index, value, num_rows, num_cols) do
    # x and y are indices in array2d,
    # so we trim D(x) and D(y) accordingly.
    removeBelow(row_index, 0)
    removeAbove(row_index, num_rows - 1)
    removeBelow(col_index, 0)
    removeAbove(col_index, num_cols - 1)
    ## D(value) is bounded by min and max of the array2d
    {arr_min, arr_max} = array2d_min_max(array2d)
    removeAbove(value, arr_max)
    removeBelow(value, arr_min)
  end

  defp maybe_reduce_domains(row_index, col_index, value, %Graph{} = graph) do
    (maybe_fix(row_index, col_index, value, graph) && :passive) ||
      (
        {updated_graph, changed?} =
          Enum.reduce(Graph.vertices(graph), {graph, false}, fn
            {:value, _} = v, acc ->
              maybe_remove_vertex(v, value, acc)

            {:row_index, _} = v, acc ->
              maybe_remove_vertex(v, row_index, acc)

            {:col_index, _} = v, acc ->
              maybe_remove_vertex(v, col_index, acc)
          end)

        ## Repeat if any reductions were made
        if changed? do
          maybe_reduce_domains(row_index, col_index, value, updated_graph)
        else
          updated_graph
        end
      )
  end

  defp maybe_remove_vertex(
         {_signature, value} = vertex,
         variable,
         {graph, _changed?} = acc,
         removal_condition \\ fn graph, vertex -> Graph.degree(graph, vertex) == 0 end
       ) do
    cond do
      !contains?(variable, value) ->
        {remove_vertex(graph, vertex), true}

      removal_condition.(graph, vertex) ->
        remove(variable, value)
        {remove_vertex(graph, vertex), true}

      true ->
        acc
    end
  end

  defp remove_vertex(graph, {:value, _value} = vertex) do
    Graph.delete_vertex(graph, vertex)
  end

  defp remove_vertex(graph, {signature, _value} = vertex)
       when signature in [:row_index, :col_index] do
    graph
    |> Graph.delete_vertex(vertex)
    ## We delete all edges related to this vertex (that is, labelled {:signature, value})
    |> then(fn graph ->
      graph
      |> Graph.edges()
      |> Enum.reduce(
        graph,
        fn edge, acc ->
          (edge.label == vertex && Graph.delete_edge(acc, edge.v1, edge.v2, edge.label)) ||
            acc
        end
      )
    end)
  end

  @impl true
  def filter(args, state, changes) do
    filter_impl(args, (state && state) || initial_state(args), changes)
  end

  def filter_impl(args, state, _changes) do
    case filter_impl(args, state) do
      :passive ->
        :passive

      updated_state ->
        if Graph.vertices(updated_state) |> Enum.empty?() do
          :fail
        else
          {:state, updated_state}
        end
    end
  end

  defp filter_impl([_array2d, row_index, col_index, value], state) do
    maybe_reduce_domains(row_index, col_index, value, state)
  end

  defp maybe_fix(row_index, col_index, value, graph) do
    ## If any 2 are fixed, fix the 3rd
    case Graph.vertices(graph) do
      [_vertex1, _vertex2, _vertex3] = triple ->
        Enum.each(
          triple,
          fn
            {:row_index, x_value} -> fix(row_index, x_value)
            {:col_index, y_value} -> fix(col_index, y_value)
            {:value, z_value} -> fix(value, z_value)
          end
        )

        true

      _more_than_one_triple ->
        false
    end
  end
end
