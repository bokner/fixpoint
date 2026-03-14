defmodule CPSolver.Examples.BinPacking.Search do
  alias CPSolver.Variable.Interface
  import CPSolver.Utils

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
      {item_vars, _rest_vars} =
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
      ## Find bin with minimal slack
      ## TODO: advanced branching, as described by Gecode docs ("two alternatives" case)
      domain = domain_values(var)

      {bin, _bin_slack} =
        Enum.reduce_while(domain, {nil, nil}, fn bin, {_min_bin, min_slack} = slack_acc ->
          load_var = Enum.at(bin_load_vars, bin - 1)

          if Interface.fixed?(load_var) do
            {:cont, slack_acc}
          else
            slack = capacity - Interface.min(load_var) - item_weight

            cond do
              slack == 0 ->
                {:halt, {bin, 0}}

              slack < 0 ->
                {:cont, slack_acc}

              slack < min_slack ->
                {:cont, {bin, slack}}

              true ->
                ## Keep current min
                {:cont, slack_acc}
            end
          end
        end)

      ## Fallback to min value, if bin is not found
      ## (can happen if all load vars are fixed)
      bin || Interface.min(var)
    end

    {choose_variable_fun, choose_value_fun}
  end
end
