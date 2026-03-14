defmodule CPSolver.Examples.BinPacking.Search do
  alias CPSolver.Variable.Interface

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
      {item_vars, rest_vars} =
        Enum.split_with(variables, fn v -> v.name in item_assignment_ids end)

      if Enum.empty?(item_vars) do
        ## All item assignments were made - we're done
        nil
      else
        %{
          variable: hd(item_vars)
        }
      end
    end

    choose_value_fun = fn %{variable: var} ->
      ## The variable is quaranteed to be unfixed `item assignment`,
      ## (see `choose_variable_fun`)

      item_weight = Map.get(item_assignment_map, var.name)
      ## Compute bin slacks (free space in bins after the item is placed)
      {_, initial_slacks} =
        Enum.reduce(bin_load_vars, {1, Map.new()}, fn load_var, {load_idx, slack_acc} ->
          {
            load_idx + 1,

            ## Gecode uses load_var.max() instead of `capacity`
            ## Not sure why, because the load never exceeds capacity,
            ## hence `capacity` and `load.max` should be equivalent
            # Interface.fixed?(load_var) && slack_acc ||
            Map.put(slack_acc, load_idx, capacity - item_weight)
          }
        end)

      ## Build final map of slacks.
      ## Iterate fixed item assignments.
      ## By construction, they are in the beginning of the list
      slack_by_bin =
        item_assignment_vars
        |> Enum.reduce_while(
          initial_slacks,
          fn assignment_var, slack_acc ->
            if assignment_var.name == var.name do
              ## end of fixed item assignments
              {:halt, slack_acc}
            else
              bin_assignment = Interface.min(assignment_var)
              ## Reduce free space for the bin
              weight = Map.get(item_assignment_map, assignment_var.name)

              {:cont,
               case Map.get(slack_acc, bin_assignment) do
                 slack when slack < weight ->
                   slack_acc

                 slack ->
                   Map.put(slack_acc, bin_assignment, slack - weight)
               end}
            end
          end
        )

      ## Find bin with minimal slack
      ## TODO: advanced branching, as described by Gecode docs ("two alternatives" case)
      ##
      Enum.reduce_while(slack_by_bin, {nil, nil}, fn {bin, slack} = el,
                                                     {_min_bin, min_slack} = acc ->
        (Interface.contains?(var, bin) &&
           cond do
             slack == 0 ->
               {:halt, el}

             slack < min_slack ->
               {:cont, el}

             true ->
               {:cont, acc}
           end) ||
          {:cont, acc}
      end)
      |> elem(0)
    end

    {choose_variable_fun, choose_value_fun}
  end
end
