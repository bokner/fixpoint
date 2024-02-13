defmodule CPSolver.Propagator.Element2D do
  use CPSolver.Propagator

  import CPSolver.Utils

  @moduledoc """
  The propagator for Element2D constraint.
  """
  def new(array2d, x, y, z) do
    new([array2d, x, y, z])
  end

  @impl true
  def variables([_array2d, x, y, z]) do
    [
      set_propagate_on(x, :domain_change),
      set_propagate_on(y, :domain_change),
      set_propagate_on(z, :domain_change)
    ]
  end

  defp initial_state([[], _x, _y, _z]) do
    throw(:fail)
  end

  defp initial_state([array2d, x, y, z]) do
    num_rows = length(array2d)
    num_cols = length(hd(array2d))

    initial_reduction(array2d, x, y, z, num_rows, num_cols)
    state = build_state(array2d, x, y, z, num_rows, num_cols)
    maybe_reduce_domains(x, y, z, state)
  end

  def build_state(array2d, x, y, z, num_rows, num_cols) do
    ## Build a graph.
    ## Three sets of vertices: ([{:z, value}], [{:x, value}], [{:y, value}])
    ## with edges from {:z, z_value} to {:x, x_value},
    ## where z_value is present in x_value row of array2d.
    ## Likewise, with edges from {:z, z_value} to {:y, y_value},
    ## where z_value is present in y_value column of array2d.
    for i <- 0..(num_rows - 1), j <- 0..(num_cols - 1), reduce: Graph.new() do
      acc ->
        if contains?(x, i) && contains?(y, j) do
          table_value = Enum.at(array2d, i) |> Enum.at(j)

          if contains?(z, table_value) do
            acc
            |> Graph.add_edge({:z, table_value}, {:x, i}, label: {:y, j})
            |> Graph.add_edge({:z, table_value}, {:y, j}, label: {:x, i})
          else
            acc
          end
        else
          acc
        end
    end
  end

  ## Try to reduce some domains
  # |> then(fn maps ->
  # maybe_reduce_domains(x, y, z, maps)
  # end)

  defp initial_reduction(array2d, x, y, z, num_rows, num_cols) do
    # x and y are indices in array2d,
    # so we trim D(x) and D(y) accordingly.
    removeBelow(x, 0)
    removeAbove(x, num_rows - 1)
    removeBelow(y, 0)
    removeAbove(y, num_cols - 1)
    ## D(z) is bounded by min and max of the array2d
    {arr_min, arr_max} = array2d_min_max(array2d)
    removeAbove(z, arr_max)
    removeBelow(z, arr_min)
  end

  defp maybe_reduce_domains(x, y, z, %Graph{} = graph) do
    {updated_graph, changed?} =
      Enum.reduce(Graph.vertices(graph), {graph, false}, fn
        {:z, _} = v, acc ->
          maybe_remove_vertex(v, z, acc)

        {:x, _} = v, acc ->
          maybe_remove_vertex(v, x, acc)

        {:y, _} = v, acc ->
          maybe_remove_vertex(v, y, acc)
      end)

    ## Repeat if any reductions were made
    if changed? do
      maybe_reduce_domains(x, y, z, updated_graph)
    else
      updated_graph
    end
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

  defp remove_vertex(graph, {:z, _value} = vertex) do
    Graph.delete_vertex(graph, vertex)
  end

  defp remove_vertex(graph, {signature, _value} = vertex) when signature in [:x, :y] do
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
  def filter(args) do
    filter(args, initial_state(args))
  end

  def filter(args, nil) do
    filter(args, initial_state(args))
  end

  @impl true

  def filter(args, state) do
    updated_state = filter_impl(args, state)

    if Graph.vertices(updated_state) |> Enum.empty?() do
      :fail
    else
      {:state, updated_state}
    end
  end

  defp filter_impl([_array2d, x, y, z], state) do
    maybe_reduce_domains(x, y, z, state)
  end
end
