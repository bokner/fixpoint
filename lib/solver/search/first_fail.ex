defmodule CPSolver.Search.Strategy.FirstFail do
  alias CPSolver.Search.Strategy
  @behaviour Strategy
  alias CPSolver.IntVariable, as: Variable

  @impl true
  def select_variable(variables) do
    {min_domain_var, _size} =
      Enum.reduce(variables, {nil, :infinity}, fn var, {_v, v_size} = acc ->
        case Variable.size(var) do
          :fail -> throw(Strategy.failed_variables_in_search_exception())
          ## Skip fixed vars
          1 -> acc
          s when s < v_size -> {var, s}
          _s -> acc
        end
      end)

    (min_domain_var && min_domain_var) || throw(Strategy.no_variable_choice_exception())
  end

  @impl true
  def select_value(variable) do
    ## Choice of value doesn't matter for first_fail
    Variable.min(variable)
  end
end
