defmodule CPSolver.Examples.BinPacking.Search do
  alias CPSolver.Variable.Interface
  alias CPSolver.Search
  alias CPSolver.Search.Partition

  @doc """
  Complete decreasing best fit branching,
  roughly as per https://www.gecode.dev/doc-latest/MPG.pdf, chapter 20
  """

  def cdbf(item_weights, item_assignment_vars, bin_load_vars, capacity) do
    ## Create a list [{item_assignment_index,  item_weight}]
    ## (will be used for matching the item assignment variables with items' weights)
    ##
    ## Note: item weights are sorted in decreasing order
    item_assignment_map =
      Enum.zip(item_assignment_vars, item_weights)
      |> Map.new(fn {var, weight} -> {var.name, weight} end)

    item_assignment_ids = MapSet.new(Map.keys(item_assignment_map))

    choose_variable_fun = fn variables ->
      ## get all (unfixed) item assignment vars
      item_vars =
        Enum.reduce_while(variables, nil, fn v, item_vars_acc ->
          item_var? = v.name in item_assignment_ids

          cond do
            #Interface.fixed?(v) ->
            #  {:cont, item_vars_acc}

            is_nil(item_vars_acc) ->
              (item_var? && {:cont, [v]}) || {:cont, nil}

            true ->
              (item_var? && {:cont, [v | item_vars_acc]}) || {:halt, item_vars_acc}
          end
        end)

      if item_vars do
        List.last(item_vars)
      end
    end

    choose_value_fun = fn var ->
      value_branching(var, bin_load_vars, item_assignment_map, capacity)
    end

    fn
      :init, _, _ ->
        :ok

      :branch, variables, _data ->
        case choose_variable_fun.(variables) do
          nil ->
            []

          selected_variable ->
            {:ok, domain_partitions} =
              Partition.partition(selected_variable, choose_value_fun)

            List.wrap(Search.partition_record(selected_variable, domain_partitions))
        end
    end
  end

  defp value_branching(var, bin_load_vars, item_assignment_map, capacity) do
    ## The variable is quaranteed to be unfixed `item assignment`,
    ## (see `choose_variable_fun`)

    item_weight = Map.get(item_assignment_map, var.name)
    ## Find bin with minimal slack
    ## TODO: advanced branching, as described by Gecode docs ("two alternatives" case)
    ##

    {bins, bin_slack} =
      Enum.reduce_while(Enum.with_index(bin_load_vars, 1), {[], nil}, fn {load_var, bin_idx},
                                                                         {min_bins, min_slack} =
                                                                           slack_acc ->
        cond do
          Interface.contains?(var, bin_idx) ->
            slack = capacity - Interface.min(load_var) - item_weight

            cond do
              Interface.fixed?(load_var) ->
                ## The bin load has already been fixed,
                ## so the item has to be there (no choice).
                ## TODO: this is the case where further branching doesn't make sense.
                ## The related issue: https://github.com/bokner/fixpoint/issues/96
                {:halt, {[bin_idx], 0}}

              slack == 0 ->
                ## Perfect fit
                {:halt, {[bin_idx], 0}}

              slack < 0 ->
                ## No fit
                {:cont, slack_acc}

              slack < min_slack ->
                ## Better fit
                {:cont, {[bin_idx], slack}}

              true ->
                ## Keep current min, add bin to the list of current min bins
                {:cont, {[bin_idx | min_bins], min_slack}}
            end

          true ->
            {:cont, slack_acc}
        end
      end)

    ## TODO:
    ## We have not implemented the branching
    ## as suggested by Gecode docs for 2-alternative branching:
    ###
    ### – Not only prune bin b from the potential bins for item i but also prune all bins with
    ##  - the same slack as b from the potential bins for all items with the same size as i
    ###
    ##  What we currently do for branching (see CPSolver.Search):
    ## - For the first branch we fix the variable with the chosen value;
    ## - For the second branch, we remove the value from the variable.
    ##
    ## - To match Gecode, we will have to remove values for several variables (the ones with the same slack)
    ##
    ## May be possible by implementing custom value selector:
    ## (see CPSolver.Search.ValueSelector.Split for an example).
    ##
    ##

    if bin_slack == 0 || length(bins) == length(bin_load_vars) do
      List.first(bins)
    else
      ## TODO: to replace with second alternative implementation
      List.first(bins)
    end
  end
end
