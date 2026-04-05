defmodule CPSolver.Examples.BinPacking.Search do
  alias CPSolver.Variable.Interface
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

    fn
      :init, _, _ ->
        :ok

      :branch, variables, _data ->
        case get_item_variables(variables, item_assignment_map) do
          nil ->
            []

          item_variables ->
            selected_variable = List.first(item_variables)

            {bins, slack, no_fit_bins} =
              value_branching(selected_variable, bin_load_vars, item_assignment_map, capacity)

            partitions(
              item_variables,
              bins,
              slack,
              no_fit_bins,
              bin_load_vars,
              item_assignment_map,
              capacity
            )
        end
    end
  end

  ## Get the (unfixed) variables with the largest item weight.
  defp get_item_variables(variables, item_assignment_map) do
    ## We rely on:
    ## - item weights sorted in descending order
    ## - the item assignment variables are adjacent to each other within the variable list;
    ## that is, all of them are located in the single block.
    Enum.reduce_while(variables, {nil, nil}, fn v, {last_item_weight, item_vars_acc} = acc ->
      ## Is variable an 'item assignment' variable?
      item_weight = Map.get(item_assignment_map, v.name)

      cond do
        is_nil(item_vars_acc) ->
          (item_weight && {:cont, {item_weight, [v]}}) || {:cont, {nil, nil}}

        true ->
          if item_weight do
            ## Found another item assignment var
            ## The weight is different?
            ## We are only interested in the vars with the identical weights
            if last_item_weight == item_weight do
              {:cont, {item_weight, [v | item_vars_acc]}}
            else
              {:halt, acc}
            end
          else
            ## The end of item assignment variables' block
            ## (these variables have to be adjacent in the list of all variables)
            {:halt, acc}
          end
      end
    end)
    |> then(fn {_, res} -> if res, do: Enum.reverse(res) end)
  end

  defp value_branching(var, bin_load_vars, item_assignment_map, capacity) do
    ## The variable is quaranteed to be unfixed `item assignment`,
    ## (see `choose_variable_fun`)

    item_weight = get_item_weight(var, item_assignment_map)
    ## Find bins with minimal slack
    ##

    {_bins, _bin_slack, _no_fit_bins} =
      Enum.reduce_while(Enum.with_index(bin_load_vars, 1), {[], nil, []}, fn
        {load_var, bin_idx}, {min_bins, min_slack, no_fit_bins} = slack_acc ->
          cond do
            Interface.contains?(var, bin_idx) ->
              slack = slack(item_weight, capacity, load_var)

              cond do
                Interface.fixed?(load_var) ->
                  ## The bin load has already been fixed,
                  ## so the item has to be there (no choice).
                  ## TODO: this is the case where further branching doesn't make sense.
                  ## The related issue: https://github.com/bokner/fixpoint/issues/96
                  {:halt, {[bin_idx], nil, []}}

                slack == 0 ->
                  ## Perfect fit
                  {:halt, {[bin_idx], 0, []}}

                slack < 0 ->
                  ## No fit
                  {:cont, {min_bins, min_slack, [bin_idx | no_fit_bins]}}

                slack < min_slack ->
                  ## Better fit
                  {:cont, {[bin_idx], slack, no_fit_bins}}

                true ->
                  ## Keep current min, add bin to the list of current min bins
                  {:cont, {[bin_idx | min_bins], min_slack, no_fit_bins}}
              end

            true ->
              {:cont, slack_acc}
          end
      end)

  end

  defp partitions(
         [selected_variable | other_item_variables] = _item_variables,
         bins,
         slack,
         no_fit_bins,
         bin_load_vars,
         item_assignment_map,
         capacity
       ) do
    bin = List.first(bins)

    cond do
      is_nil(bin) ->
        throw(:fail)

      slack in [0, nil] ->
        ## Perfect fit or the bin being fixed.
        ## We only need a single partition.
        ##
        [
          Partition.fixed_value_partition(selected_variable, bin)
        ]

      Enum.empty?(no_fit_bins) ->
        [
          Partition.fixed_value_partition(selected_variable, bin),
          Partition.removed_value_partition(selected_variable, bin)
        ]

      true ->
        ## As suggested by Gecode docs for 2-alternative branching
        ## (https://www.gecode.dev/doc-latest/MPG.pdf, chapter 20):
        ###
        ### – Not only prune bin b from the potential bins for item i,
        ##    but also prune all bins with the same slack as b
        ##    from the potential bins for all items with the same size as i
        ##
        ##  At this point, all item variables have the same size as the first item variable;
        ##  For each item variable, we will iterate over bin load vars to
        ##  identify the ones with the same slack as computed for the first variable.
        ##
        prune_partition =
          Enum.reduce(
            other_item_variables,
            Partition.remove_multiple_values_partition(selected_variable, no_fit_bins),
            fn variable, acc ->
              w = get_item_weight(variable, item_assignment_map)

              {_idx, acc} =
                Enum.reduce(bin_load_vars, {1, acc}, fn load_var, {bin, acc2} ->
                  {bin + 1,
                   cond do
                     !Interface.contains?(variable, bin) ->
                       acc2

                     Interface.fixed?(load_var) ->
                       Map.put(acc2, variable.id, fn variable ->
                         Interface.fix(variable, bin)
                       end)

                     slack(w, capacity, load_var) == slack ->
                       Map.put(acc2, variable.id, fn variable ->
                         Interface.remove(variable, bin)
                       end)

                     true ->
                       acc2
                   end}
                end)

              acc
            end
          )

        [
          Partition.fixed_value_partition(selected_variable, bin),
          prune_partition
        ]
    end

  end

  defp slack(item_weight, capacity, load_variable) do
    capacity - Interface.min(load_variable) - item_weight
  end

  defp get_item_weight(variable, item_assignment_map) do
    Map.get(item_assignment_map, variable.name)
  end
end
