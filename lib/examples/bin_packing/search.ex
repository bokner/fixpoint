defmodule CPSolver.Examples.BinPacking.Search do
  alias CPSolver.Variable.Interface

  @doc """
  Complete decreasing best fit branching,
  roughly as per https://www.gecode.dev/doc-latest/MPG.pdf, chapter 20
  """
  def cdbf(item_weights, item_assignment_vars, bin_load_vars) do
    ## Create a list [{item_assignment_index,  item_weight}]
    ## (will be used for matching the item assignment variables with items' weights)
    ##
    ## Note: item weights are sorted in decreasing order
    item_assignment_ids = MapSet.new(item_assignment_vars, fn v -> v.name end)
    item_assignment_list =
      Enum.zip(item_weights, item_assignment_vars)

    choose_variable_fun = fn variables ->
      ## get all (unfixed) item assignment vars
      {item_vars, _rest_vars} = Enum.split_with(variables, fn v -> v.name in item_assignment_ids end)

      if Enum.empty?(item_vars) do
        ## All item assignments were made - we're done
        nil
      else
        ## keep the entries in item assignment list that correspond to unfixed variables.
        hd(item_vars)
      end
    end

    choose_value_fun = fn var ->
      ## TODO: choose based on variable kind (Enum.max/1 may be better for loads etc...)
      # interval_start = Interface.min(var)
      # interval_end = Interface.max(var)
      # median = div(interval_end - interval_start, 2)
      # Enum.find(median..interval_end - 1,
      #   Enum.random([interval_start, interval_end]),
      #     fn x -> Interface.contains?(var, x)
      #   end)
      Interface.max(var)
    end

    {choose_variable_fun, choose_value_fun}
  end
end
